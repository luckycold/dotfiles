# TrueNAS Plex Docker DNS Recovery

Use this when Plex is reachable on the LAN port but appears unavailable in Plex/MyPlex, remote access, or related automation after a TrueNAS DNS/app-routing change.

## Symptom pattern

- TrueNAS `plex` app is `RUNNING` and Docker container is `healthy`.
- `curl -I http://<nas-ip>:32400/web/index.html` returns `200 OK`.
- Inside the Plex container, DNS lookups for `plex.tv` fail.
- `/etc/resolv.conf` inside the container shows Docker embedded DNS with stale external server metadata, for example:
  - `nameserver 127.0.0.11`
  - `# ExtServers: [host(192.168.0.2)]`
- On Luke's TrueNAS host, `192.168.0.2` is the Traefik app IP, not the DNS service. The desired host DNS is `192.168.1.157`.

## Root cause

Docker containers keep resolver configuration from the time their network/container was created. If the TrueNAS host DNS is corrected later, existing app containers may still use stale Docker `ExtServers` until the TrueNAS app is redeployed.

For Plex this can look like a Plex outage even though the local server process and port are healthy, because Plex cannot contact `plex.tv`, pubsub, certificate, or MyPlex APIs.

## Safe recovery

Run from a trusted shell on the TrueNAS host:

```bash
# Inspect host DNS first; it should be the AdGuard/NAS IP, not Traefik.
midclt call network.configuration.config | jq '{nameserver1,nameserver2,nameserver3,domains}'
getent hosts plex.tv

# Confirm Plex local port is healthy.
curl -sS -m 8 -I http://127.0.0.1:32400/identity
curl -sS -m 8 -I http://<nas-ip>:32400/web/index.html

# Check container resolver.
docker exec ix-plex-plex-1 sh -lc 'cat /etc/resolv.conf; getent hosts plex.tv || true'

# Redeploy the TrueNAS app so Docker recreates the container/network resolver.
midclt call -j app.redeploy plex
```

If related Plex automation apps also show stale `ExtServers`, redeploy them too:

```bash
midclt call -j app.redeploy jelly-plex
midclt call -j app.redeploy plex-auto-languages
```

## Verification

```bash
# App/container state
midclt call app.query | jq -r '.[] | select(.name|IN("plex","jelly-plex","plex-auto-languages")) | [.name,.state,(.active_workloads.container_details[0].state // "")] | @tsv'
docker ps --format 'table {{.Names}}\t{{.Status}}' | egrep '(ix-plex-plex|jelly-plex|plex-auto-languages)'

# Resolver regenerated from fixed host DNS.
for c in ix-plex-plex-1 jelly-plex ix-plex-auto-languages-plex-auto-languages-1; do
  echo "-- $c --"
  docker exec "$c" sh -lc 'grep ExtServers /etc/resolv.conf; getent hosts plex.tv >/dev/null && echo dns_ok || echo dns_failed'
done

# Plex local and upstream connectivity.
docker exec ix-plex-plex-1 sh -lc 'curl -fsS -m 8 -I https://plex.tv | sed -n "1,8p"'
curl -sS -m 8 -I http://127.0.0.1:32400/identity
curl -sS -m 8 -I http://<nas-ip>:32400/web/index.html
```

Optional stronger verification: read `PlexOnlineToken` from `Preferences.xml` without printing it, call local `/myplex/account` and `https://plex.tv/api/resources.xml`, and report only non-secret availability fields such as `mappingState`, `presence`, local/remote connection addresses, and ports. Mask tokens in any log excerpts.

## Pitfalls

- Do not conclude Plex is fully healthy from `container healthy` or local HTTP 200 alone; verify container DNS and `plex.tv` reachability.
- Do not change private-domain hostname rewrites to the NAS UI IP just because DNS is involved; resolve the distinct Traefik and DNS addresses from `~/.agents/private-context.md`.
- Prefer TrueNAS `app.redeploy` over manual Docker edits so the deployment remains UI-managed.
- Do not print Plex tokens from `Preferences.xml` or logs.