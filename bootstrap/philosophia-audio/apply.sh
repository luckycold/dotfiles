#!/bin/bash

set -euo pipefail

expected_host=philosophia

if [[ $(hostname) != "${expected_host}" ]]; then
  printf 'This bootstrap is only for %s; current host is %s\n' "${expected_host}" "$(hostname)" >&2
  exit 1
fi

bootstrap_dir=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
target_dir="${HOME}/.config/wireplumber/wireplumber.conf.d"
target_file="${target_dir}/60-disable-auto-pause-playback.conf"

install -d -m 755 "${target_dir}"
install -m 644 \
  "${bootstrap_dir}/wireplumber/wireplumber.conf.d/60-disable-auto-pause-playback.conf" \
  "${target_file}"

printf 'Installed WirePlumber auto-pause override to %s\n' "${target_file}"
printf 'Restart WirePlumber to apply it: systemctl --user restart wireplumber\n'
