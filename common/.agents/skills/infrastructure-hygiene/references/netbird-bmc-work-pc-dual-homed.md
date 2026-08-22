# NetBird routed-network access from a dual-homed workstation

Use this when a routed private network is unstable on the home LAN but works through another uplink. Resolve the workstation SSH target, routed subnet, test endpoint, interface names, and managed SSH-agent settings from `~/.agents/private-context.md`; do not copy those values into this reference or reports.

## Diagnosis

1. Check whether Ethernet and Wi-Fi are simultaneously up with default routes.
2. Inspect `netbird status -d` for the selected local ICE endpoint and the peer advertising the routed network.
3. Compare `ip route get <private-endpoint>` with the intended uplink.
4. Use bounded ping and HTTPS probes. Small requests succeeding while a browser partially loads can indicate path-MTU trouble rather than application failure.
5. If the workstation is docked, disable Wi-Fi and retest using Ethernet only. A hotspot can change interface selection and mask the dual-homing problem.
6. If single-homing does not fix it, inspect the NetBird interface MTU and test path MTU/MSS behavior.

## Boundaries

- Keep the exact employer network, endpoint, device names, IP addresses, usernames, tracking entities, and agent socket paths in the private context.
- Do not attribute the failure to NAS or DNS without live route and resolver evidence.
- Keep diagnosis read-only unless the user explicitly asks for a network configuration change.