# TrueNAS Traefik app routing and certificates

Use this when exposing a TrueNAS App through Luke's Traefik TrueNAS app.

## Current layout

- Traefik dynamic file provider directory: `/mnt/Apps/Applications/traefik/dynamic/`
- Traefik cert mount source: `/mnt/Apps/Applications/traefik/certs/`
- TrueNAS-managed certificates: `/etc/certificates/`
- Traefik entrypoints are bound to `192.168.0.2:80` and `192.168.0.2:443`.

## Add a route

Create a small dynamic YAML file rather than editing a large shared route file when possible:

```yaml
http:
  routers:
    immich:
      rule: "Host(`<private-photo-host>`)"
      entryPoints: [websecure]
      tls: {}
      priority: 100
      service: immich

  services:
    immich:
      loadBalancer:
        servers:
          - url: "http://192.168.1.157:30041"
```

Validate YAML on the NAS before relying on Traefik to load it.

## Domains outside existing wildcard certs

If the hostname is not covered by the current Traefik wildcard certificate, issue a TrueNAS ACME certificate for that exact host and reference it from the dynamic file:

```yaml
tls:
  certificates:
    - certFile: "/certs/photos-cold-haus.crt"
      keyFile: "/certs/photos-cold-haus.key"
```

TrueNAS middleware patterns:

1. Create a CSR with `midclt call certificate.create ...` for `CERTIFICATE_CREATE_CSR`. This is a job method; without `-j` the call can return only a job id.
2. Create the ACME certificate with `midclt call -j certificate.create ...` using:
   - `create_type: CERTIFICATE_CREATE_ACME`
   - `csr_id: <csr id>`
   - `tos: true`
   - `acme_directory_uri: https://acme-v02.api.letsencrypt.org/directory`
   - `dns_mapping: {"<domain>": <authenticator id>}`
   - `renew_days: 30`
3. Delete temporary CSR objects with `midclt call -j certificate.delete <id> false`; `certificate.delete` is also a job method.
4. Copy the resulting `.crt` and `.key` from `/etc/certificates/` into `/mnt/Apps/Applications/traefik/certs/`, preserving the ownership/mode expected by the Traefik mount.
5. Touch the dynamic YAML file after copying certs so Traefik's file provider reloads.

## Renewal sync

A TrueNAS cron job can keep Traefik's mounted certs in sync after ACME renewal. The established script location is:

- `/mnt/Apps/Applications/traefik/sync-certs.sh`

Pattern:

- Iterate over `/etc/certificates/*.crt` and `*.key`.
- Only copy files whose basename already exists in `/mnt/Apps/Applications/traefik/certs/` so unrelated TrueNAS certs are not exposed to Traefik.
- Use `cmp -s` to avoid unnecessary reloads.
- On change, `install -m 0770 -o lucky -g lucky` the file, then `touch` dynamic YAML files to trigger reload.

## Verification

From the Hermes container or another client:

```bash
dig +short <host>
echo | openssl s_client -connect <host>:443 -servername <host> 2>/dev/null \
  | openssl x509 -noout -subject -dates -ext subjectAltName
curl -sS -I --max-time 15 https://<host>/
```

A good result for app exposure is: DNS points to Traefik, the served certificate subject/SAN matches the hostname, and the HTTPS probe returns the expected app response without `-k`.
