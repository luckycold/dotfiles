# TrueNAS Cloudflared / AdGuard DNS Origin Resolution

Use this when Cloudflare Tunnel reports an origin as unreachable even though the TrueNAS app itself is running. Resolve the private public host, internal origin, app wildcard, and AdGuard hostnames from `~/.agents/private-context.md`.

## Failure signature

Cloudflared logs show an internal origin name resolving to public Cloudflare edge IPs instead of the NAS, then timing out on the app port:

```text
originService=http://<private-internal-origin>:<port>
dial tcp 104.21.x.x:30041: i/o timeout
dial tcp 172.67.x.x:30041: i/o timeout
```

This means cloudflared/Docker DNS is resolving through public DNS, not the local AdGuard rewrite path.

## Diagnostic sequence

Run from the NAS over SSH:

```bash
midclt call app.query | jq -r '.[] | select(.name|test("adguard|cloudflared|immich|traefik")) | [.name,.state,.version] | @tsv'
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -Ei 'adguard|cloudflared|immich|traefik'
ss -tulpen | grep -E ':(53|80|443|30041|30069)\b' || true
midclt call network.configuration.config | jq '{nameserver1,nameserver2,nameserver3,domains}'
rc=$(docker inspect ix-cloudflared-cloudflared-1 --format '{{.ResolvConfPath}}'); sed -n '1,80p' "$rc"
for h in "$PRIVATE_INTERNAL_ORIGIN" "$PRIVATE_PUBLIC_HOST"; do dig +short @"$ADGUARD_IP" "$h" A; done
```

Also verify the app path independently:

```bash
curl -kIsS http://192.168.1.157:30041/ | sed -n '1,8p'
curl -kIsS --resolve "$PRIVATE_PUBLIC_HOST:443:$TRAEFIK_IP" "https://$PRIVATE_PUBLIC_HOST/" | sed -n '1,8p'
```

If these are healthy but Cloudflared logs public Cloudflare IPs for the private internal origin, fix DNS rather than the app.

## Corrective pattern

1. Determine where AdGuard is actually publishing DNS:

```bash
docker ps --filter name=adguard --format '{{.Names}} {{.Ports}}'
ss -tulpen | grep ':53\b'
```

2. Point TrueNAS host DNS at that active listener. On Luke's NAS, the known-good state after the July 2026 outage was AdGuard DNS on `192.168.0.2:53`:

```bash
midclt call network.configuration.update '{"nameserver1":"192.168.0.2","nameserver2":"1.1.1.1","nameserver3":"9.9.9.9"}'
```

3. Ensure AdGuard rewrites return local origins:

```yaml
<private-internal-origin>: <backend-ip>
<private-app-wildcard>: <traefik-ip>
<private-public-host>: <traefik-ip>
```

Avoid bogus rewrite answers like `answer: A`; use concrete IPs/CNAMEs.

4. Restart AdGuard if the config file was edited directly, then cycle affected apps so Docker regenerates `/etc/resolv.conf`:

```bash
docker restart ix-adguard-home-adguard-1
midclt call -j app.stop cloudflared
midclt call -j app.start cloudflared
```

5. Verify cloudflared's resolver now contains the active AdGuard listener:

```text
ExtServers: [host(192.168.0.2) host(1.1.1.1) host(9.9.9.9)]
```

6. Verify externally and locally:

```bash
curl -kIsS "https://$PRIVATE_PUBLIC_HOST/api/server/ping" | sed -n '1,12p'
for h in "$PRIVATE_PUBLIC_HOST" "$PRIVATE_ADGUARD_HOST" "$PRIVATE_ADGUARD_LAN_HOST"; do
  curl -kIsS --resolve "$h:443:192.168.0.2" "https://$h/" | sed -n '1,8p'
done
```

## AdGuard via Traefik

If the private AdGuard host returns Traefik `404` while the direct backend returns `/login.html`, add a small dedicated Traefik dynamic route:

```yaml
http:
  routers:
    adguard:
      rule: "Host(`<private-adguard-host>`) || Host(`<private-adguard-lan-host>`)"
      entryPoints: [websecure]
      tls: {}
      priority: 100
      service: adguard

  services:
    adguard:
      loadBalancer:
        servers:
          - url: "http://192.168.1.157:30069"
```

A nested private AdGuard hostname may still fail at Cloudflare TLS if the edge certificate does not cover that wildcard depth; local Traefik success proves the NAS route is correct.