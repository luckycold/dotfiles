# TrueNAS AdGuard DNS binding vs Traefik app routing

Session-derived note for Luke's TrueNAS SCALE host (`192.168.1.157`) where the same host also carries the legacy/secondary service IP `192.168.0.2`.

## Topology observed

- Host bridge `br0` has both `192.168.1.157/23` and `192.168.0.2/23`.
- TrueNAS UI/nginx listens on `192.168.1.157:80/443`.
- Traefik app listens on `192.168.0.2:80/443`.
- AdGuard Home web UI listens on `192.168.1.157:30069`.
- **DNS:** Luke also uses **`192.168.0.2` as an alternate DNS IP** on the NAS (same `br0` host). Verify live with `dig @192.168.0.2` and `dig @192.168.1.157` — publish/bind may differ by app config over time. Do not tell Luke ".0.2 is not DNS" from Traefik notes alone.
- AdGuard DNS is often published on `192.168.1.157` when DHCP should hand clients that IP first.
- AdGuard rewrites for the private app wildcard intentionally send HTTPS app hostnames to Traefik, not to the TrueNAS UI. Resolve exact names and addresses from `~/.agents/private-context.md`.
- Hosts that must **not** land on Traefik need an **exact** rewrite that wins over `*.lan.1al.cc` → `192.168.0.2`. Verified: `pbs.lan.1al.cc` → hypervisor PBS and `pbs-nas.lan.1al.cc` → the TrueNAS PBS VM. Edit `/mnt/Apps/Applications/adguard-home/config/AdGuardHome.yaml` `filtering.rewrites`, then **restart** `ix-adguard-home-adguard-1`. `SIGHUP` does not reload that YAML.

## Important pitfall

Do **not** blindly rewrite private app hostnames from the Traefik address to the NAS UI address just because apps and DNS share the NAS. That would bypass Traefik/Authelia and likely break routes unless Traefik is also moved.

## Safe update pattern for AdGuard DNS bind IP

1. Inspect current app config:
   ```bash
   midclt call app.config adguard-home | jq '.network'
   ```
2. Update only `network.dns_port.host_ips` via TrueNAS middleware, preserving the rest of the app config. Avoid editing rendered compose files directly.
3. Example pattern:
   ```bash
   python3 - <<'PY'
   import json, subprocess
   app = 'adguard-home'
   cfg = json.loads(subprocess.check_output(['midclt', 'call', 'app.config', app]))
   cfg['network']['dns_port']['host_ips'] = ['192.168.1.157']
   cfg.pop('ix_context', None)
   open('/tmp/adguard-update-values.json', 'w').write(json.dumps({'values': cfg}))
   PY
   midclt call -j app.update adguard-home "$(cat /tmp/adguard-update-values.json)"
   ```
4. Verify:
   ```bash
   midclt call app.query '[["name","=","adguard-home"]]' | jq -r '.[0].state'
   ss -H -ltnup '( sport = :53 or sport = :30069 )'
   dig +time=1 +tries=1 +short @"$DNS_IP" "$PRIVATE_DNS_HOST" A
   ```

## Verification distinction

- `dig @192.168.1.157 <host> A` verifies the DNS service is reachable at the requested DNS IP.
- `curl --resolve "$PRIVATE_APP_HOST:443:$TRAEFIK_IP" "https://$PRIVATE_APP_HOST/"` verifies Traefik app routing.
- Resolving the same host to the NAS UI address will likely hit TrueNAS nginx/UI instead of Traefik; that is evidence **not** to change DNS rewrites without moving Traefik.