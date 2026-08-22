# UniFi DHCP DNS + TrueNAS dual-IP diagnostics

This reference captures the concrete commands, failure modes, and verification that resolved "internal domains only resolve on VPN" for Luke's network. The root cause was the Ubiquiti UniFi router handing out the wrong primary DNS via DHCP on the main LAN, despite AdGuard rewrites being correct.

## IP Roles on TrueNAS (br0)

Current live state as of 2026-07-09:

- 192.168.1.157/23 — TrueNAS primary / NAS UI. **Not currently listening on DNS :53** after the AdGuard bind move; queries to `192.168.1.157:53` refuse.
- 192.168.0.2/23 — secondary alias on the same interface. This is the Traefik/web-service target for the private app wildcard and the **current AdGuard DNS listener**.

AdGuard (Docker app `ix-adguard-home-adguard-1`) inside binds to 0.0.0.0:53, but the container's current port publish is explicit:
`53/tcp -> 192.168.0.2:53`
`53/udp -> 192.168.0.2:53`

Historical note: the original phone DNS incident was diagnosed when AdGuard only answered on `192.168.1.157` and `192.168.0.2:53` refused. Later the stack was intentionally moved/forwarded so LAN DHCP can hand out `192.168.0.2` as DNS. Always verify with `ss -tulpen | grep :53` and `docker inspect ix-adguard-home-adguard-1` before changing DHCP.

## Client Symptoms

Historical private-service issue: phones could not resolve internal names on Wi-Fi unless the VPN profile forced the then-correct DNS server. The underlying class is DHCP handing clients a DNS server/search domain that does not match the resolver that actually has AdGuard rewrites.

In the observed search-domain issue, UniFi advertised a private device domain while AdGuard had only the older private namespace. Clients expanding a short NAS name through DHCP therefore received NXDOMAIN. Resolve both private domains from `~/.agents/private-context.md`.

## Repro / Diagnostic Commands (run from Hermes container or any LAN host)
```bash
# Verify which IP currently answers DNS
ssh -i "$NAS_SSH_KEY" -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" "$NAS_SSH_TARGET" 'ss -tulpen | grep :53'
ssh -i "$NAS_SSH_KEY" -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" "$NAS_SSH_TARGET" \
  'docker inspect ix-adguard-home-adguard-1 --format "{{json .NetworkSettings.Ports}}"'

# Current positive controls
nslookup tr 192.168.0.2
nslookup "$PRIVATE_NAS_HOST" 192.168.0.2

# Current failing search-domain FQDN, unless a rewrite/zone was added
nslookup "$PRIVATE_SEARCH_HOST" 192.168.0.2
nslookup "$PRIVATE_SEARCH_HOST" 192.168.0.1

# Confirm the service itself works if DNS is forced to the target
curl -kI --resolve "$PRIVATE_SEARCH_HOST:443:192.168.1.157" "https://$PRIVATE_SEARCH_HOST/"
```

## Fixing the Router (UniFi Controller REST API)
No SSH to the router (connection refused on 22). Use the controller API directly.

### API-key path (preferred when saved)
1. Resolve the scoped wrapper, vault, and item names from `~/.agents/private-context.md`, then locate the API key with a short REASON (viewer role is sufficient for read):
   ```bash
   export PROTON_PASS_AGENT_REASON="Locate UniFi API key for DHCP DNS fix"
   "$PROTON_PASS_AGENT" item list "$PROTON_PASS_VAULT" --output json
   ```

2. One-shot mutation (export the key in the current shell only; redact everywhere):
   ```bash
   export KEY="[REDACTED]"
   curl -s -k -H "X-API-Key: $KEY" \
     "https://192.168.0.1/proxy/network/api/s/default/rest/networkconf" \
     | python3 -c '...'   # parse and print the Default network object
   ```

3. Re-verify the network object after the PUT.

### SSO/MFA fallback path (worked July 2026)
If no UniFi API key is saved, resolve the approved controller-login item from the private context and use it only in memory; never print password, TOTP, cookies, or CSRF tokens.

- `POST https://192.168.0.1/api/auth/login` with JSON `{username,password,rememberMe:false,token:<totp>}` returns a `TOKEN` cookie and CSRF headers.
- UniFi writes require the CSRF header **exactly as `X-Csrf-Token`** (case observed in headers); carrying no/empty token returns `403 Forbidden` even if reads work.
- DHCP config read endpoint: `/proxy/network/api/s/default/rest/networkconf`.
- Local DNS records endpoint: `/proxy/network/v2/api/site/default/static-dns`.
- Exact A record create shape that worked:
  ```json
  {"enabled":true,"key":"<private-search-host>","record_type":"A","value":"<target-ip>","ttl":0,"port":0,"priority":0,"weight":0}
  ```
- After creating a record, poll DNS until propagation:
  ```bash
  dig +time=3 +tries=1 +short @192.168.0.1 "$PRIVATE_SEARCH_HOST" A
  ```

## Post-Fix Client Action
Router/DNS changes are instantaneous for new lookups, but existing clients may retain old DHCP options/cache until renewal:
- Forget the WiFi network + rejoin (most reliable), or reboot / toggle airplane mode.
- Flush browser/OS DNS cache where possible.
- If LAN split DNS matters, avoid public DNS as a DHCP secondary unless you accept occasional NXDOMAIN/leakage from clients that race/select the public server.

For current state, clients should receive the intended primary DNS, and AdGuard should contain or forward every DHCP search-domain FQDN expected in use.

## Search-domain / rewrite failure pattern

If a private search-domain FQDN fails while an older private namespace still works, check three separate layers:

1. **UniFi DHCP handoff:** inspect the advertised `domain_name` and DNS addresses.
2. **Active DNS listener:** verify `192.168.0.2:53` vs `192.168.1.157:53`; as of 2026-07-09 AdGuard answers on `.0.2`, while `.1.157:53` refuses.
3. **AdGuard rewrites/forwarding:** verify that the current private search domain is forwarded or has the required exact records, not only records for an older namespace.

Preferred fixes depend on the namespace intent:

### If the private domain is a machine/device hostname zone
- Treat UniFi gateway DNS as authoritative-ish for DHCP/local device names under that zone.
- If clients use AdGuard as universal DNS, configure domain-specific forwarding to UniFi instead of masking the whole zone with an AdGuard wildcard.
- Avoid broad rewrites unless app wildcarding is explicitly desired; they can hide UniFi device hostnames.
- Keep exact overrides only where necessary.

### If the private domain is an app/Traefik wildcard zone
- Add an explicit AdGuard rewrite for the required host first.
- Add a controlled wildcard only when all unknown names should land on Traefik.

General hygiene:
- Or change UniFi `domain_name` back to the namespace that already has internal DNS records and renew client DHCP leases.
- Remove public DNS (`1.1.1.1`) from LAN DHCP if split-horizon names must be reliable; public secondaries can produce NXDOMAIN when clients race or select them.

## Cross References
- `truenas-adguard-dns-and-traefik-ips.md` (the TrueNAS side of the same IP distinction)
- `proton-pass-cli` skill (REASON discipline, session repair, viewer role write limitations, redaction rules)

This pattern (proton-pass discovery → direct one-shot API mutation on router → host-level + docker diagnostics for IP binding) is reusable for any future "LAN clients can't see internal rewrites or services" incidents.