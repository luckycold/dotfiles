# TrueNAS Docker DNS recovery after host resolver misconfiguration

Use this when TrueNAS Apps are running/restarting but containers fail DNS through Docker's embedded resolver (`127.0.0.11`), **or** when Cloudflared dials public Cloudflare IPs for internal origins (see also `truenas-cloudflared-adguard-dns-origin-resolution.md`).

## Failure signature

Examples seen during an Authelia/Cloudflared/Traefik outage:

```text
lookup smtp.protonmail.ch on 127.0.0.11:53: server misbehaving
lookup time.cloudflare.com on 127.0.0.11:53: server misbehaving
Couldn't resolve SRV record region1.v2.argotunnel.com ... on 127.0.0.11:53: server misbehaving
```

Cloudflared private-origin loop signature:

```text
originService=http://<private-internal-origin>:<port>
dial tcp 104.21.x.x:30041: i/o timeout
dial tcp 172.67.x.x:30041: i/o timeout
```

## Root cause pattern

On Luke's TrueNAS host, `192.168.0.2` is Traefik HTTP/HTTPS and **often also** AdGuard's DNS publish IP — verify live with `ss`/`docker ps`, do not assume DNS is always on `192.168.1.157`. Docker containers inherit host resolvers as ExtServers:

```text
# in container /etc/resolv.conf
nameserver 127.0.0.11
# ExtServers: [host(<nameserver1>)]
```

**Invariant:** `nameserver1` must be the IP where AdGuard actually publishes `:53`. If host DNS points elsewhere, queries refuse then fall through to public DNS and private internal origins can become Cloudflare anycast. Resolve exact addresses and domains from `~/.agents/private-context.md`.

## Investigation commands

```bash
ssh -o IdentityAgent=none -o BatchMode=yes -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" -i "$NAS_SSH_KEY" "$NAS_SSH_TARGET"

midclt call network.configuration.config | jq '{nameserver1,nameserver2,nameserver3,domains}'
cat /etc/resolv.conf
ss -H -tuln 'sport = :53'

dig +time=2 +tries=1 @192.168.0.2 smtp.protonmail.ch A +short || true
dig +time=2 +tries=1 @192.168.1.157 smtp.protonmail.ch A +short || true
dig +time=2 +tries=1 @"$ADGUARD_IP" "$PRIVATE_INTERNAL_ORIGIN" A +short

docker ps --format '{{.Names}}\t{{.Status}}' | egrep -i 'traefik|authelia|cloudflared|ldap|auth'
docker logs --tail=120 ix-cloudflared-cloudflared-1 2>&1 | tail -80
```

To check inherited Docker DNS from a shell-capable container:

```bash
docker exec ix-traefik-traefik-1 sh -c 'cat /etc/resolv.conf; nslookup smtp.protonmail.ch 2>&1 | head -20'
```

## Fix

Update the TrueNAS host resolver to the **live AdGuard listener**, then redeploy/cycle affected Apps so Docker regenerates each container's resolver file. Include external fallback resolvers so middleware/catalog sync still works during boot before AdGuard is up.

```bash
# Example when AdGuard publishes on .0.2 (verify with ss/docker first):
midclt call network.configuration.update '{"nameserver1":"192.168.0.2","nameserver2":"1.1.1.1","nameserver3":"9.9.9.9"}' \
  | jq '{nameserver1,nameserver2,nameserver3,domains}'
# When AdGuard publishes on .157 instead, use nameserver1: 192.168.1.157

for app in authelia traefik cloudflared; do
  midclt call -j app.redeploy "$app" || true
done
# cloudflared also accepts app.stop + app.start when redeploy is awkward
```

Do not specify DNS one-by-one for every app unless a specific chart needs special split-DNS behavior. TrueNAS Apps inherit the host resolver through Docker's embedded DNS. After any host resolver change, existing containers may continue showing the old `ExtServers` until recreated, so redeploy/cycle running apps once to refresh them.

Use `app.start <name>` instead of `app.redeploy <name>` if an app is fully stopped and redeploy is not appropriate, but redeploy/cycle is usually the right post-DNS-change action because it refreshes Docker's embedded DNS upstream.

## Full app sweep after a resolver fix

After the host resolver is fixed, do not assume only the visibly broken apps need redeploying. Long-running containers keep the old Docker embedded DNS upstream in `/etc/resolv.conf` until recreated. Inventory every running TrueNAS app container and redeploy any app whose ExtServers do **not** match the live AdGuard listener IP.

Useful compact scan pattern from the NAS:

```bash
midclt call app.query > /tmp/apps.json
python3 - <<'PY'
import json, subprocess, re
apps=json.load(open('/tmp/apps.json'))
state={a['name']:a.get('state') for a in apps}
container_to_app={}
for a in apps:
  for d in ((a.get('active_workloads') or {}).get('container_details') or []):
    if d.get('id'):
      container_to_app[d['id'][:12]]=a['name']
stale=set()
for line in subprocess.check_output(['docker','ps','--format','{{.ID}}\t{{.Names}}'], text=True).splitlines():
  cid,name=line.split('\t',1)
  app=container_to_app.get(cid[:12])
  if app is None:
    candidates=[a for a in state if name.startswith(f'ix-{a}-') or name == a or name.startswith(f'{a}-')]
    app=max(candidates, key=len) if candidates else name
  try:
    resolv=subprocess.check_output(['docker','exec',name,'cat','/etc/resolv.conf'], stderr=subprocess.STDOUT, text=True, timeout=8)
  except Exception:
    continue
  # Flag containers whose ExtServers still point only at the wrong host IP.
  # Adjust the "wrong" check to whatever is NOT the live AdGuard listener.
  if 'ExtServers' in resolv and '192.168.0.2' not in resolv and '192.168.1.157' in resolv:
    stale.add(app)
print('\n'.join(sorted(stale)))
PY
```

Redeploy/cycle stale apps sequentially. Prefer verifying live AdGuard `:53` first. Keep `adguard-home` last if you must restart DNS itself.

## Verification

```bash
midclt call app.query | jq -r '.[] | select(.name=="authelia" or .name=="traefik" or .name=="cloudflared") | [.name,.state,((.active_workloads.container_details // []) | map(.service_name+":"+.state) | join(","))] | @tsv' | sort

for c in ix-authelia-authelia-1 ix-traefik-traefik-1; do
  docker exec "$c" sh -c 'grep -E "ExtServers|nameserver" /etc/resolv.conf; nslookup smtp.protonmail.ch 2>&1 | head -10'
done

docker logs --since=2m ix-cloudflared-cloudflared-1 2>&1 \
  | egrep -i 'registered tunnel|dns resolved|lookup|no such host|unable to reach|error|fail|pass' \
  | tail -80
```

Luke-specific route check: the private route host should return HTTP 200 from ninerouter. If cloudflared logs show `lookup tr on 127.0.0.11:53: no such host` for a short-name origin, preserve/fix the scoped AdGuard rewrites or update the tunnel origin to a non-ambiguous local target. Then redeploy cloudflared to flush origin DNS.

Expected (example when AdGuard DNS is on `.0.2`):

```text
# ExtServers: [host(192.168.0.2) host(1.1.1.1) host(9.9.9.9)]
authelia RUNNING ... authelia:running
traefik RUNNING ... traefik:running
cloudflared RUNNING ... cloudflared:running
Registered tunnel connection ...
# dig @AdGuard-IP <private-internal-origin> A → private backend, not public Cloudflare
```

External smoke checks:

```bash
curl -skI --max-time 15 "https://$PRIVATE_AUTH_HOST/" | sed -n '1,16p'
curl -skI --max-time 15 "https://$PRIVATE_PROTECTED_APP_HOST/" | sed -n '1,16p'
curl -skI --max-time 15 "https://$PRIVATE_PHOTO_HOST/api/server/ping" | sed -n '1,12p'
```

## Pitfalls

- Do not treat `127.0.0.11` itself as the broken service; it is Docker's embedded resolver. Inspect the `ExtServers` comment in container `/etc/resolv.conf` to see the bad upstream.
- Do not repoint wildcard/app host rewrites from `192.168.0.2` to `192.168.1.157`; Traefik HTTP/HTTPS still belongs on `192.168.0.2`.
- Restarting only the failed app may leave Traefik or other long-lived containers with stale `ExtServers`; redeploy the reverse proxy/auth/tunnel layer after host DNS changes.
- Cloudflared images may not include `sh`; use logs and app state for verification rather than assuming `docker exec ... sh` works.
- Cloudflared precheck can log regional QUIC/TCP warnings even while tunnel connections register successfully; distinguish those from DNS-resolution failures and actual tunnel registration failure.
