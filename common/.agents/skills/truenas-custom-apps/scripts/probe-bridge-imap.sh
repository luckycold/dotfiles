#!/usr/bin/env bash
# CAPABILITY probe for proton-bridge IMAP (TrueNAS or tunneled 127.0.0.1:1143).
# Exit 0 if response looks like IMAP; exit 1 otherwise. No secrets printed.
set -euo pipefail

LOCAL_PORT="${BRIDGE_IMAP_PORT:-1143}"
PROBE_TIMEOUT="${PROBE_TIMEOUT:-8}"

imap_probe() {
  # stdin: optional pre-connected nc; args: host port
  printf 'a0 CAPABILITY\r\n' | timeout "$PROBE_TIMEOUT" nc "$1" "$2" 2>/dev/null || true
}

check_output() {
  local out="$1"
  if echo "$out" | grep -qiE 'CAPABILITY|a0 OK|\* OK'; then
    echo "imap_ok"
    return 0
  fi
  if [ -n "$(echo "$out" | tr -d '[:space:]')" ]; then
    echo "imap_unexpected_response"
    echo "$out" | head -3
    return 1
  fi
  echo "imap_no_response"
  return 1
}

# 1) Local (Hermes tunnel or local bridge)
out="$(imap_probe 127.0.0.1 "$LOCAL_PORT")"
if check_output "$out"; then
  exit 0
fi

# 2) NAS host direct. Private values come from ~/.agents/private-context.md.
if [ -n "${NAS_SSH_TARGET:-}" ] &&
   [ -r "${NAS_SSH_KEY:-}" ] &&
   [ -r "${NAS_KNOWN_HOSTS:-}" ]; then
  out="$(ssh \
    -o BatchMode=yes \
    -o IdentityAgent=none \
    -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" \
    -i "$NAS_SSH_KEY" \
    "$NAS_SSH_TARGET" \
    "printf 'a0 CAPABILITY\\r\\n' | timeout ${PROBE_TIMEOUT} nc 127.0.0.1 ${LOCAL_PORT}" 2>/dev/null || true)"
  if check_output "$out"; then
    exit 0
  fi
fi

exit 1