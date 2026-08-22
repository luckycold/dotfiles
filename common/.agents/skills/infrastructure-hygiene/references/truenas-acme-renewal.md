# TrueNAS ACME Certificate Renewal

Use this reference when Luke asks to renew certificates on his TrueNAS SCALE host.

## Prerequisites

- Resolve `NAS_SSH_TARGET`, `NAS_SSH_KEY`, and `NAS_KNOWN_HOSTS` from `~/.agents/private-context.md`.
- Require a pre-verified host key; do not accept a new or changed key automatically.
- Do not print ACME authenticator tokens, private keys, or full credential JSON.

## Read current certificate state

```bash
ssh -i "$NAS_SSH_KEY" \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" \
  "$NAS_SSH_TARGET" \
  'python3 - <<"PY"
import json, subprocess
certs=json.loads(subprocess.check_output(["midclt","call","certificate.query"]))
print("ID | name | ACME | until | renew_days | CN | SAN")
for c in certs:
    print("{} | {} | {} | {} | {} | {} | {}".format(
        c.get("id"), c.get("name"), bool(c.get("acme")), c.get("until"),
        c.get("renew_days"), c.get("common"), c.get("san")))
PY'
```

## Run renewal

```bash
ssh -i "$NAS_SSH_KEY" \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" \
  "$NAS_SSH_TARGET" \
  'midclt call -j -jp description certificate.renew_certs'
```

`certificate.renew_certs` only renews certificates whose remaining lifetime is less than `renew_days` (default observed logic: ACME certs with `until - now < renew_days`).

## Verify job and post-state

```bash
ssh -i "$NAS_SSH_KEY" \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" \
  "$NAS_SSH_TARGET" \
  'python3 - <<"PY"
import json, subprocess
certs=json.loads(subprocess.check_output(["midclt","call","certificate.query"]))
print("ACME certificate status after renewal attempt:")
for c in certs:
    if c.get("acme"):
        print("id={} name={} until={} renew_days={} parsed={} expired={}".format(
            c.get("id"), c.get("name"), c.get("until"), c.get("renew_days"),
            c.get("parsed"), c.get("expired")))
filters=json.dumps([["method", "=", "certificate.renew_certs"]])
options=json.dumps({"order_by": ["-id"], "limit": 3})
jobs=json.loads(subprocess.check_output(["midclt","call","core.get_jobs", filters, options]))
print("Recent renew jobs:")
for j in jobs:
    print("job={} state={} error={}".format(
        j.get("id"), j.get("state"), (j.get("error") or "")[:220].replace("\n"," ")))
PY'
```

## Cloudflare IP-restricted token failure

Observed failure signature:

```text
DNS challenge failed for <private-domain>
[EFAULT] Failed to perform cloudflare challenge for '<private-domain>' domain:
Error determining zone_id: 9109 Cannot use the access token from location: <WAN IP>.
Please confirm that you have supplied valid Cloudflare API credentials.
```

Interpretation: the Cloudflare API token configured in TrueNAS's ACME DNS Authenticator is valid enough to reach Cloudflare, but Cloudflare rejects it from the current public source IP. Fix by updating the Cloudflare token client-IP restriction to include the NAS/home WAN IP shown in the error, or replacing the TrueNAS ACME authenticator token with a DNS-edit token that is not restricted away from that IP.

Do not keep retrying the renewal unchanged; the job will fail repeatedly until the Cloudflare token policy/secret is corrected.
