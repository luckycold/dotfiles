# Laptop / workstation LAN reconnaissance from the Home Assistant add-on

Use this when Luke asks Hermes to access or identify a laptop/workstation from the HA add-on container.

## Known-good sequence

1. **Start with Home Assistant device trackers.** Query `device_tracker` entities and match on the user-provided hostname, friendly name, MAC, or prior memory. HA/UniFi often has the authoritative IP even when mDNS/DNS from the container hangs or lacks LAN visibility.
2. **Keep private topology out of the skill.** Resolve known hostnames, users, addresses, device identifiers, and the SSH-agent socket from `~/.agents/private-context.md`. Do not save credentials, private keys, vault IDs, item IDs, or transient failures.
3. **Verify local credential plumbing before SSH.** Export the private-context socket as `SSH_AUTH_SOCK`, run `ssh-add -l`, and use `BatchMode=yes` so commands fail cleanly without prompts.
4. **Try authenticated OS commands first.** Example:
   ```bash
   SSH_AUTH_SOCK="$PROTON_SSH_AUTH_SOCK" \
     ssh -o BatchMode=yes -o ConnectTimeout=8 <user>@<host> \
       'uname -a; cat /etc/os-release 2>/dev/null || true; sw_vers 2>/dev/null || true'
   ```
5. **If the add-on container cannot reach ports or mDNS, pivot through an already trusted LAN host listed in the private context.** From there, use `getent hosts`, `ip neigh`, `ping`, and read-only `nmap`.
6. **When SSH is filtered, use fingerprinting and label confidence.** Example from a LAN host:
   ```bash
   nmap -sV -O --version-all -Pn -p 22,53,80,443,445,548,5900,3389,5432 --osscan-guess HOST
   ```
   Report this as an estimate, not confirmed OS, unless authenticated commands succeed.

## Private inventory

Resolve known device names, users, tracking entities, IP/MAC addresses, and prior reconnaissance results from `~/.agents/private-context.md`. Do not copy them into this reference or reports.

## Pitfalls

- Do not conclude SSH is disabled solely from the HA add-on container; test from a same-LAN host if possible.
- Avoid long combined `getent`/mDNS commands in the add-on; they can hang. Use short timeouts or HA state instead.
- Do not persist raw Proton Pass item/vault/share IDs while searching for SSH credentials.
