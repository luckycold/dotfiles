# T3 Connect on an always-on TrueNAS host

Use this when T3 Connect should expose an always-on TrueNAS coding environment through T3 Code. Resolve the SSH target and private operational values at runtime; never store the account email, authorization code, challenge URL, or relay credentials here.

## Deployment model

T3's supported background-service path is a user systemd unit, not a TrueNAS Custom App. Keep its runtime and mutable data under a persistent Apps-pool directory such as `<apps-pool>/Applications/t3code`, bind the local server only to loopback, and use T3's managed outbound relay for remote access.

For a root-owned installation, enable lingering so the user manager survives logout:

```bash
loginctl enable-linger root
systemctl --user enable t3code.service
```

## Native dependency failure on the TrueNAS host

`npx t3 service install` can fail while building `node-pty` when the appliance host lacks `make` or a compiler. Do not add an unmanaged host build toolchain merely to complete the install.

Instead:

1. Select a supported prebuilt Node.js release for the NAS architecture and place it under the persistent T3 base directory.
2. In a temporary Debian/glibc container with the same architecture and Node release, install T3 and compile its native dependencies.
3. Copy the resulting runtime tree into a versioned directory under the persistent T3 base.
4. Run T3's service installer from that runtime.
5. Add a systemd user-unit drop-in that prepends the persistent Node `bin` directory and T3 runtime to `PATH`; then run `systemctl --user daemon-reload`.

The build container's libc and architecture must match the NAS host closely enough for `node-pty` to load. Validate by starting the real service, not merely by checking that `npm install` completed.

## Headless account link

Run the link command in an interactive terminal multiplexer so SSH disconnects do not discard the prompt:

```bash
tmux new-session -s t3-connect
t3 connect link --headless --base-dir "$T3_BASE"
```

Open the displayed URL in an authenticated browser, approve the narrowly scoped T3 CLI consent, and enter the one-time authorization code only into the waiting terminal. Treat the URL, state, challenge, and code as transient secrets: do not put them in shell history, logs, reports, or skills.

After authorization is stored, restart the service so it provisions the environment link and managed relay:

```bash
systemctl --user restart t3code.service
t3 connect status --base-dir "$T3_BASE"
```

## Verification

Require all of the following:

- `t3code.service` is enabled, active, and `SubState=running`.
- `loginctl show-user root -p Linger --value` returns `yes` for a root-owned service.
- `NRestarts=0` after a clean startup.
- The T3 listener is bound to loopback, not an all-interface address.
- `t3 connect status` reports exposure enabled, a stored credential, a provisioned environment link, and an available relay.
- In the client, **Settings → Connections → Remote environments** lists the host as `Available · Relay online`; select **Connect** to make it the active environment.
- Recent service logs contain no errors.

A stored credential with `Environment link: pending server startup` is not complete. Restart the service and wait for provisioning. A provisioned relay also does not automatically select the remote environment in each client, and the project sidebar does not act as a machine list. Connect to the host under Connections, then add or select a project separately. Do not expose the local T3 port through router NAT or Traefik when the managed relay is working.
