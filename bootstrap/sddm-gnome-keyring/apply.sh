#!/bin/bash

set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  printf 'Run as root: sudo %s\n' "$0" >&2
  exit 1
fi

install -D -m 644 \
  "$(dirname "$0")/etc/pam.d/sddm" \
  /etc/pam.d/sddm

chown root:root /etc/pam.d/sddm

printf 'Installed SDDM PAM config with GNOME keyring hooks to /etc/pam.d/sddm\n'
