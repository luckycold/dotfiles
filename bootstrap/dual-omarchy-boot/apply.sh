#!/bin/bash

set -euo pipefail

# Coordinate two Omarchy installs that each own their own ESP. The main
# machine firmware should keep booting the personal/internal Limine; the work
# install is reached from a Limine menu entry instead of taking over NVRAM.

INTERNAL_ESP_GUID=${INTERNAL_ESP_GUID:-e83b9ba8-c715-42e7-91a1-42017213c4e9}
EXTERNAL_ESP_GUID=${EXTERNAL_ESP_GUID:-1b44d6d5-a68e-450f-8763-17b9e99b09cf}
LIMINE_EFI_PATH=${LIMINE_EFI_PATH:-/EFI/limine/limine_x64.efi}

usage() {
  cat <<EOF
Usage: sudo $0 --role personal|work

Roles:
  personal  Keep this OS as the firmware default and add a Work OS entry.
  work      Add a Personal OS entry and prevent this OS from taking over UEFI NVRAM.

Overrides:
  INTERNAL_ESP_GUID=<guid>  Default: ${INTERNAL_ESP_GUID}
  EXTERNAL_ESP_GUID=<guid>  Default: ${EXTERNAL_ESP_GUID}
  LIMINE_EFI_PATH=<path>    Default: ${LIMINE_EFI_PATH}
EOF
}

require_root() {
  if [[ ${EUID} -ne 0 ]]; then
    printf 'Run as root: sudo %s --role personal|work\n' "$0" >&2
    exit 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

part_device_for_guid() {
  local guid=$1 path
  path=$(readlink -f "/dev/disk/by-partuuid/${guid}" 2>/dev/null || true)
  [[ -b ${path} ]] || return 1
  printf '%s\n' "$path"
}

# Remove all existing UEFI entries that match the given label.
# This is defensive for removable drives where firmware or previous runs
# can leave behind stale or duplicate named entries.
remove_uefi_entries_by_label() {
  local label=$1
  local id

  while IFS= read -r id; do
    [[ -n $id ]] || continue
    efibootmgr -b "$id" -B >/dev/null 2>&1 || true
  done < <(efibootmgr | sed -n "s/^Boot\([0-9A-F]\{4\}\)[* ] ${label}\([[:space:]].*\)\?$/\1/p")
}

ensure_uefi_entry() {
  local label=$1 guid=$2 efi_path=$3 part disk partnum loader_path

  part=$(part_device_for_guid "$guid") || return 0

  # Only remove/recreate entries once the target partition is visible. This
  # avoids deleting a usable removable-drive entry during an unplugged run.
  remove_uefi_entries_by_label "$label"

  disk="/dev/$(lsblk -no PKNAME "$part")"
  partnum=$(lsblk -no PARTN "$part")
  loader_path=${efi_path//\//\\}

  [[ -b ${disk} && -n ${partnum} ]] || return 0
  efibootmgr -c -d "$disk" -p "$partnum" -L "$label" -l "$loader_path" >/dev/null || true
}

entry_id_for_label() {
  local label=$1
  efibootmgr | sed -n "s/^Boot\([0-9A-F]\{4\}\)[* ] ${label}\([[:space:]].*\)\?$/\1/p" | head -n1
}

keep_limine_first() {
  local limine_entry current_order entry new_order
  limine_entry=$(entry_id_for_label Limine)
  [[ -n ${limine_entry} ]] || return 0

  current_order=$(efibootmgr | sed -n 's/^BootOrder: //p' | head -n1)
  [[ -n ${current_order} ]] || return 0

  new_order=${limine_entry}
  IFS=',' read -ra entries <<<"$current_order"
  for entry in "${entries[@]}"; do
    [[ ${entry} == "${limine_entry}" ]] && continue
    new_order+=",${entry}"
  done

  efibootmgr -o "$new_order" >/dev/null
}

set_limine_default() {
  local key=$1 value=$2 path=/etc/default/limine tmp

  install -d -m 0755 /etc/default
  touch "$path"
  cp -a "$path" "${path}.bak.$(date +%Y%m%d%H%M%S)"

  tmp=$(mktemp)
  grep -Ev "^${key}=" "$path" >"$tmp" || true
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  install -m 0644 "$tmp" "$path"
  rm -f "$tmp"
}

install_peer_hook() {
  local title=$1 protocol=$2 value=$3 hook=/etc/boot/hooks/post.d/88-omarchy-peer-os

  install -d -m 0755 /etc/boot/hooks/post.d

  cat >"$hook" <<EOF
#!/usr/bin/env bash
set -euo pipefail

config=/boot/limine.conf
title='${title}'
protocol='${protocol}'
value='${value}'

[[ -f "\$config" ]] || exit 0

if grep -Fxq "/\$title" "\$config" && { grep -Fxq "path: \$value" "\$config" || grep -Fxq "entry: \$value" "\$config"; }; then
  exit 0
fi

tmp=\$(mktemp)
trap 'rm -f "\$tmp"' EXIT

perl -0pe 's{\n/(?:Work OS \(external drive\)|Personal OS \(internal drive\))\n.*?(?=\n/(?:\+|[^/])|\z)}{\n}s' "\$config" >"\$tmp"

{
  printf '\n/%s\n' "\$title"
  printf 'comment: Boots peer Omarchy install via persistent UEFI entry\n'
  printf 'protocol: %s\n' "\$protocol"
  if [[ "\$protocol" == 'efi_boot_entry' ]]; then
    printf 'entry: %s\n' "\$value"
  else
    printf 'path: %s\n' "\$value"
  fi
} >>"\$tmp"

install -m 0644 "\$tmp" "\$config"
EOF

  chmod 0755 "$hook"
}

main() {
  local role=
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --role)
        role=${2:-}
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 1
        ;;
    esac
  done

  local title protocol value
  case "$role" in
    personal)
      title='Work OS (external drive)'
      protocol='efi_boot_entry'
      value='Work OS'
      ;;
    work)
      title='Personal OS (internal drive)'
      protocol='efi_boot_entry'
      value='Personal OS'
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac

  require_root
  require_cmd efibootmgr
  require_cmd grep
  require_cmd install
  require_cmd lsblk
  require_cmd mktemp
  require_cmd perl
  require_cmd readlink

  case "$role" in
    personal)
      ensure_uefi_entry 'Work OS' "$EXTERNAL_ESP_GUID" "$LIMINE_EFI_PATH"
      keep_limine_first
      ;;
    work)
      set_limine_default SKIP_UEFI yes
      ensure_uefi_entry 'Personal OS' "$INTERNAL_ESP_GUID" "$LIMINE_EFI_PATH"
      ;;
  esac

  install_peer_hook "$title" "$protocol" "$value"

  # Always ensure the local Limine menu has the peer entry and is enrolled.
  /etc/boot/hooks/post.d/88-omarchy-peer-os

  if command -v limine-enroll-config >/dev/null 2>&1; then
    limine-enroll-config
  fi

  # Defensive verification after ensure step.
  if [[ "$role" == "personal" ]]; then
    if part_device_for_guid "$EXTERNAL_ESP_GUID" >/dev/null 2>&1; then
      if [[ -n $(entry_id_for_label 'Work OS') ]]; then
        echo "Verified: 'Work OS' UEFI entry exists and drive is present."
      else
        echo "Warning: External drive detected but 'Work OS' UEFI entry is missing after ensure."
      fi
    else
      echo "Note: External drive (PARTUUID $EXTERNAL_ESP_GUID) not currently visible."
      echo "      'Work OS' entry will be created next time the script runs with the drive plugged in."
    fi
  fi

  if [[ "$role" == "work" ]]; then
    if part_device_for_guid "$INTERNAL_ESP_GUID" >/dev/null 2>&1; then
      if [[ -n $(entry_id_for_label 'Personal OS') ]]; then
        echo "Verified: 'Personal OS' UEFI entry exists and internal drive is visible."
      else
        echo "Warning: 'Personal OS' UEFI entry is missing."
      fi
    fi
  fi

  cat <<EOF
Dual Omarchy boot coordination applied.

Role: ${role}
Peer entry: ${title}
Peer handoff: ${protocol} ${value}
Hook: /etc/boot/hooks/post.d/88-omarchy-peer-os
EOF
}

main "$@"
