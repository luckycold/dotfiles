# Catalog App Network/Port Host IP Edits + Bridge Workarounds

Concrete pattern from AdGuard Home on a dual-IP TrueNAS host. Resolve exact addresses and the private test hostname from `~/.agents/private-context.md`. The goal is to make the alias the client-visible DNS server that DHCP distributes while preserving the internal service rewrite.

## Key Files
- `/mnt/.ix-apps/app_configs/adguard-home/versions/1.3.12/user_config.yaml` (or latest version dir)
- The `network` block controls published ports for catalog apps.

## Edit Pattern
```yaml
network:
  dns_port:
    bind_mode: "published"
    host_ips:
    - "192.168.0.2"     # target client-facing resolver IP here
    port_number: 53
  # web_port and other services often stay on the primary or are handled by Traefik labels
  host_network: false
```

Always:
1. `cp user_config.yaml user_config.yaml.bak.$(date +%s)`
2. Use python:
   ```python
   import yaml
   with open(...) as f: data = yaml.safe_load(f)
   data["network"]["dns_port"]["host_ips"] = ["192.168.0.2"]
   with open(...) as f: yaml.dump(data, f, default_flow_style=False, sort_keys=False)
   ```

## Redeploy Gotcha (the main pitfall)
- `midclt call app.stop adguard-home && sleep 10 && midclt call app.start adguard-home`
- Frequently the running container **keeps the old publish** (`docker ps` and `docker inspect ... Ports` still show `192.168.1.157:53->53`).
- `ss -tuln | grep :53` confirms only the old IP is listening from the host.
- The ix-apps runtime appears to treat port host_ip changes as requiring a deeper update/upgrade cycle (or UI-triggered redeploy) rather than a simple stop/start.

## Immediate Bridge (when user goal is "192.168.0.2 must be the DNS server now")
Use host iptables DNAT so queries to the alias are forwarded to the current real listener. This makes .0.2 act as the resolver without waiting for the app.

```bash
# PREROUTING for inbound client traffic
iptables -t nat -A PREROUTING -d 192.168.0.2 -p udp --dport 53 -j DNAT --to-destination 192.168.1.157:53
iptables -t nat -A PREROUTING -d 192.168.0.2 -p tcp --dport 53 -j DNAT --to-destination 192.168.1.157:53

# OUTPUT for tests originating on the NAS itself
iptables -t nat -A OUTPUT -d 192.168.0.2 -p udp --dport 53 -j DNAT --to-destination 192.168.1.157:53
iptables -t nat -A OUTPUT -d 192.168.0.2 -p tcp --dport 53 -j DNAT --to-destination 192.168.1.157:53
```

Verification:
- `nslookup "$PRIVATE_TEST_HOST" "$CLIENT_DNS_IP"` should return the intended private rewrite target.
- `ss -tuln | grep 192.168.0.2:53` will still show nothing (the forward is at nat level)
- `docker inspect ix-adguard-home-adguard-1 --format '{{json .NetworkSettings.Ports}}' | grep 53`

## Persistence
```bash
cat > /root/apply-dns-forward.sh << 'EOP'
#!/bin/bash
# idempotent
iptables -t nat -C PREROUTING -d 192.168.0.2 -p udp --dport 53 -j DNAT --to-destination 192.168.1.157:53 2>/dev/null || \
  iptables -t nat -A PREROUTING -d 192.168.0.2 -p udp --dport 53 -j DNAT --to-destination 192.168.1.157:53
# (repeat for tcp + both OUTPUT rules)
echo "DNS forward for 192.168.0.2:53 applied $(date)"
EOP
chmod +x /root/apply-dns-forward.sh

# crude but reliable on TrueNAS
echo "@reboot root /root/apply-dns-forward.sh" >> /etc/crontab
```

(Alternative: put the script in a TrueNAS Post Init Script via the UI for better visibility.)

## Cleanup Later
Once the catalog app is updated/redeployed and `docker inspect` shows the publish has moved to 192.168.0.2:53 natively, the iptables rules (and cron) can be removed. The earlier user_config edit will then be sufficient.

## Related UniFi Side (for completeness)
After the TrueNAS side is ready, flip the LAN "Default" network via UniFi API:
- PUT to `/proxy/network/api/s/default/rest/networkconf/<network _id>`
- Set `dhcpd_dns_1: "192.168.0.2"`, `dhcpd_dns_2: "1.1.1.1"`
- Force clients to renew (forget WiFi + rejoin is most reliable).

This pattern appears when a dual-IP host (primary for one role, alias for services) + catalog app port pinning + desire for a particular IP to be the "DNS server" clients actually talk to.

## Session Context (2026-06)
- App: adguard-home (v0.107.77 container)
- Host IPs: 192.168.1.157 (primary, originally published) + 192.168.0.2 (alias, desired resolver + service target)
- Inside container bind_hosts was already 0.0.0.0; the limitation was the Docker publish in the generated compose.
- User explicit correction: "make the DNS server 192.168.0.2 then ... when I do a DNS lookup it uses .0.2 so that Seer can be seen".

Update this reference whenever a similar catalog app port migration or dual-IP resolver requirement appears.