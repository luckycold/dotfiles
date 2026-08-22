# UniFi WAN port forwarding through the controller API

Use this for deliberate public TCP/UDP exposure when the UniFi console is reachable but rules need to be created and verified programmatically. Keep credentials out of argv, logs, memory, and reference files.

## Authentication discovery

Prefer an existing scoped UniFi API key:

```bash
curl -skS -H "X-API-Key: $UNIFI_KEY" \
  https://GATEWAY/proxy/network/integration/v1/sites
```

A `200` with a non-empty `data` array confirms the key and site visibility. The same key can work with the legacy Network application endpoints under `/proxy/network/api/s/<site>/rest/...` even though it was validated against `integration/v1`.

If Proton Pass discovery is needed, search **login items only** (`item list <vault> --filter-type login`); email aliases with UniFi-looking titles are not login credentials and correctly lack `username`/`password` fields. A viewer-scoped Pass agent cannot save a newly supplied API key. Use it only for reads, consume a user-supplied key in memory for the task, and leave a manual secure-storage step. Never preserve raw API keys in conversational memory.

## Read and mirror existing rule schema

For the default site:

```bash
BASE=https://GATEWAY/proxy/network/api/s/default/rest/portforward
curl -skS -H "X-API-Key: $UNIFI_KEY" "$BASE"
```

Inspect current rules before mutation. Common fields in a working rule are:

```json
{
  "name": "Service TLS",
  "enabled": true,
  "pfwd_interface": "wan",
  "proto": "tcp",
  "src": "any",
  "destination_ip": "any",
  "dst_port": "993",
  "fwd": "192.168.x.y",
  "fwd_port": "993",
  "log": false
}
```

Ports are strings in the observed legacy schema. Use `tcp`, `udp`, or `tcp_udp` only as intended; do not broaden a TCP-only service to both protocols without a reason.

## Idempotent create/update sequence

1. GET all current rules.
2. Treat `(dst_port, fwd, fwd_port, proto/interface)` as the primary collision check, not the display name alone.
3. If an equivalent enabled rule already exists, do not create a duplicate.
4. POST the JSON body to the same `rest/portforward` collection endpoint.
5. Require HTTP success and response `meta.rc == "ok"`.
6. GET the collection again and print only non-secret rule metadata: name, enabled, interface, protocol, external port, target IP, and target port.
7. Check for unrelated rules sharing the same WAN port before and after creation.

## End-to-end verification

A rule existing in UniFi proves configuration, not reachability. Verify all layers:

- service is listening on the destination host/port;
- host/container publish points at the expected backend protocol;
- public DNS resolves to the current WAN address;
- several genuinely external TCP checker nodes reach the WAN port;
- a protocol-aware TLS or application test succeeds;
- authentication succeeds when the service requires it.

For `check-host.net/check-tcp`, success may be represented as a result containing an address and numeric connection time, e.g. `[{"address":"203.0.113.10","time":0.2}]`, rather than the literal word `Connected`. Parse the shape, not only status words.

## Cleanup and credential hygiene

- Unset the API key after use and remove temporary cookie/response files.
- If a raw key was previously saved in assistant/conversation memory, delete that memory once the task no longer needs it; store it in Proton Pass or another approved secret store instead.
- Record rule intent and verification results, never the API key.
- On rollback, list rules first, identify the exact rule ID from live state, delete only that rule, and verify it disappeared; never guess IDs.
