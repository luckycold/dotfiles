#!/bin/bash

set -euo pipefail

# Coordinate two Omarchy installs that each own their own ESP. Firmware
# should keep booting the personal/internal disk; Work is reached from a
# Limine menu entry instead of taking over NVRAM. Each OS signs only its
# own ESP. Do not rewrite peer boot binaries or change BootOrder unless
# explicitly requested.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
INTERNAL_ESP_GUID=${INTERNAL_ESP_GUID:-e83b9ba8-c715-42e7-91a1-42017213c4e9}
EXTERNAL_ESP_GUID=${EXTERNAL_ESP_GUID:-1b44d6d5-a68e-450f-8763-17b9e99b09cf}
LIMINE_EFI_PATH=${LIMINE_EFI_PATH:-/EFI/limine/limine_x64.efi}

usage() {
  cat <<EOF
Usage: sudo $0 --role personal|work [--update-firmware-entries] [--repair-peer]

Roles:
  personal  Add a Work OS Limine menu entry. Leaves firmware BootOrder alone.
  work      Add a Personal OS menu entry and set SKIP_UEFI=yes.

Options:
  --update-firmware-entries  Personal only: create/reorder a named Limine
                             NVRAM entry. Skip this on a proven install;
                             it changes PCR 1.
  --repair-peer              Re-copy, enroll, and sign the peer ESP with
                             this OS's sbctl keys. Skip this on a proven
                             dual-key setup; each OS should sign itself.

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

mounted_path_for_device() {
  local device=$1 mount_path
  mount_path=$(findmnt -nr -o TARGET --source "$device" | head -n1)
  [[ -n ${mount_path} ]] || return 1
  printf '%s\n' "$mount_path"
}

repair_limine_for_esp_guid() {
  local guid=$1 part mount_path mounted_here=0 config_path limine_path fallback_path config_hash

  part=$(part_device_for_guid "$guid") || return 0

  if mount_path=$(mounted_path_for_device "$part"); then
    mounted_here=0
  else
    mount_path=$(mktemp -d)
    mount "$part" "$mount_path" || {
      rmdir "$mount_path" 2>/dev/null || true
      return 0
    }
    mounted_here=1
  fi

  config_path="$mount_path/limine.conf"
  limine_path="$mount_path/EFI/limine/limine_x64.efi"
  fallback_path="$mount_path/EFI/BOOT/BOOTX64.EFI"

  if [[ -f "$config_path" && -f /usr/share/limine/BOOTX64.EFI ]]; then
    install -D -m 0644 /usr/share/limine/BOOTX64.EFI "$limine_path"
    config_hash=$(b2sum "$config_path" | awk '{print $1}')
    limine enroll-config "$limine_path" "$config_hash"
    sbctl remove-file "$limine_path" >/dev/null 2>&1 || true
    sbctl sign -s "$limine_path"
    install -D -m 0644 "$limine_path" "$fallback_path"
    sbctl remove-file "$fallback_path" >/dev/null 2>&1 || true
    sbctl sign -s "$fallback_path" || true
  fi

  if (( mounted_here == 1 )); then
    umount "$mount_path"
    rmdir "$mount_path" 2>/dev/null || true
  fi
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
  printf 'comment: Boots peer Omarchy install by ESP GUID\n'
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

install_theme_hook() {
  local hook=/etc/boot/hooks/post.d/87-limine-theme

  install -d -m 0755 /etc/boot/hooks/post.d
  install -m 0644 "$SCRIPT_DIR/limine-theme.conf" /etc/limine-theme.conf
  install -m 0755 "$SCRIPT_DIR/hooks/87-limine-theme" "$hook"
}

install_fallback_sync_hook() {
  local hook=/etc/boot/hooks/post.d/91-limine-sync-fallback

  install -d -m 0755 /etc/boot/hooks/post.d


  cat >"$hook" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

esp=/boot
main="$esp/EFI/limine/limine_x64.efi"
fallback="$esp/EFI/BOOT/BOOTX64.EFI"

[[ -f "$main" ]] || exit 0
install -D -m 0644 "$main" "$fallback"
EOF

  chmod 0755 "$hook"
}

install_default_linux_entry_hook() {
  local hook=/etc/boot/hooks/post.d/89-limine-default-linux-entry

  install -d -m 0755 /etc/boot/hooks/post.d

  cat >"$hook" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config=/boot/limine.conf
[[ -f "$config" ]] || exit 0

default_entry=$(awk '
  /^\/\+/ {
    os = substr($0, 3)
    next
  }
  os && /^[[:space:]]*\/\/[^/]/ {
    kernel = $0
    sub(/^[[:space:]]*\/\//, "", kernel)
    print os "/" kernel
    exit
  }
' "$config")

[[ -n "$default_entry" ]] || exit 0

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

awk -v default_entry="$default_entry" '
  /^default_entry:/ {
    if (!done) {
      print "default_entry: " default_entry
      done = 1
    }
    next
  }
  { print }
  END {
    if (!done) {
      print "default_entry: " default_entry
    }
  }
' "$config" >"$tmp"

cmp -s "$tmp" "$config" || install -m 0644 "$tmp" "$config"
EOF

  chmod 0755 "$hook"
}

main() {
  local role= update_firmware_entries=0 repair_peer=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --role)
        role=${2:-}
        shift 2
        ;;
      --update-firmware-entries)
        update_firmware_entries=1
        shift
        ;;
      --repair-peer)
        repair_peer=1
        shift
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
      protocol='efi'
      value="guid(${EXTERNAL_ESP_GUID}):${LIMINE_EFI_PATH}"
      ;;
    work)
      title='Personal OS (internal drive)'
      protocol='efi'
      value="guid(${INTERNAL_ESP_GUID}):${LIMINE_EFI_PATH}"
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac

  require_root
  require_cmd awk
  require_cmd b2sum
  require_cmd efibootmgr
  require_cmd grep
  require_cmd install
  require_cmd findmnt
  require_cmd limine
  require_cmd limine-update
  require_cmd lsblk
  require_cmd mktemp
  require_cmd mount
  require_cmd perl
  require_cmd python3
  require_cmd readlink
  require_cmd sbctl
  require_cmd umount

  set_limine_default FIND_BOOTLOADERS no

  case "$role" in
    personal)
      if (( repair_peer == 1 )); then
        repair_limine_for_esp_guid "$EXTERNAL_ESP_GUID"
      fi
      if (( update_firmware_entries == 1 )); then
        remove_uefi_entries_by_label 'Work OS'
        ensure_uefi_entry 'Limine' "$INTERNAL_ESP_GUID" "$LIMINE_EFI_PATH"
        keep_limine_first
      fi
      ;;
    work)
      set_limine_default SKIP_UEFI yes
      if (( repair_peer == 1 )); then
        repair_limine_for_esp_guid "$INTERNAL_ESP_GUID"
      fi
      if (( update_firmware_entries == 1 )); then
        remove_uefi_entries_by_label 'Personal OS'
      fi
      ;;
  esac

  install_theme_hook
  install_peer_hook "$title" "$protocol" "$value"
  install_default_linux_entry_hook
  install_fallback_sync_hook

  limine-update

  # Always ensure the local Limine menu has the peer entry, theme, and enrollment.
  /etc/boot/hooks/post.d/88-omarchy-peer-os
  /etc/boot/hooks/post.d/89-limine-default-linux-entry
  /etc/boot/hooks/post.d/87-limine-theme

  if command -v limine-enroll-config >/dev/null 2>&1; then
    limine-enroll-config
  fi

  /etc/boot/hooks/post.d/91-limine-sync-fallback

  # Defensive verification after ensure step.
  if [[ "$role" == "personal" ]]; then
    if part_device_for_guid "$EXTERNAL_ESP_GUID" >/dev/null 2>&1; then
      echo "Verified: external Work OS ESP is visible for GUID chainload."
    else
      echo "Note: External drive (PARTUUID $EXTERNAL_ESP_GUID) not currently visible."
      echo "      Work OS menu entry will remain present but will only boot when the drive is visible."
    fi
  fi

  if [[ "$role" == "work" ]]; then
    if part_device_for_guid "$INTERNAL_ESP_GUID" >/dev/null 2>&1; then
      echo "Verified: internal Personal OS ESP is visible for GUID chainload."
    fi
  fi

  cat <<EOF
Dual Omarchy boot coordination applied.

Role: ${role}
Peer entry: ${title}
Peer handoff: ${protocol} ${value}
Theme: /etc/limine-theme.conf via /etc/boot/hooks/post.d/87-limine-theme
Firmware NVRAM changes: $( (( update_firmware_entries == 1 )) && echo yes || echo no )
Peer ESP rewrite: $( (( repair_peer == 1 )) && echo yes || echo no )
EOF
}

main "$@"
