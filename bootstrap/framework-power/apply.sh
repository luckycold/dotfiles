#!/bin/bash

set -euo pipefail

# Personal bootstrap for Luke's current Framework AMD + Thunderbolt dock +
# NVIDIA eGPU setup. This is intentionally hardware-specific.

require_root() {
  if [[ ${EUID} -ne 0 ]]; then
    printf 'Run as root: sudo %s\n' "$0" >&2
    exit 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

backup_file() {
  local path=$1
  if [[ -f ${path} && ! -L ${path} ]]; then
    cp -a "${path}" "${path}.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

backup_path() {
  local path=$1
  if [[ -e ${path} || -L ${path} ]]; then
    mv "${path}" "${path}.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

ensure_real_directory() {
  local path=$1
  local mode=${2:-755}

  if [[ -L ${path} ]]; then
    backup_path "${path}"
  fi

  install -d -m "${mode}" "${path}"
  chown root:root "${path}"
}

materialize_file() {
  local source_path=$1
  local target_path=$2
  local mode=${3:-644}

  if [[ ! -f ${source_path} ]]; then
    printf 'Missing source file: %s\n' "${source_path}" >&2
    exit 1
  fi

  if [[ -e ${target_path} || -L ${target_path} ]]; then
    backup_file "${target_path}"
    rm -f "${target_path}"
  fi

  install -D -m "${mode}" "${source_path}" "${target_path}"
  chown root:root "${target_path}"
}

main() {
  require_root

  require_cmd btrfs
  require_cmd blkid
  require_cmd efibootmgr
  require_cmd findmnt
  require_cmd limine-mkinitcpio
  require_cmd limine-update
  require_cmd lsblk
  require_cmd python3
  require_cmd systemd-tmpfiles
  require_cmd udevadm

  local bootstrap_dir root_source root_partition partuuid resume_offset

  bootstrap_dir=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)

  root_source=$(findmnt -no SOURCE /)
  root_source=${root_source%%\[*}
  root_partition=$(lsblk -srno PATH "${root_source}" | sed -n '2p')
  if [[ -z ${root_partition} ]]; then
    printf 'Could not determine encrypted root partition for %s\n' "${root_source}" >&2
    exit 1
  fi

  partuuid=$(blkid -s PARTUUID -o value "${root_partition}")
  resume_offset=$(btrfs inspect-internal map-swapfile -r /swap/swapfile)

  backup_file /etc/default/limine

  python3 - "${partuuid}" "${resume_offset}" <<'PY'
from pathlib import Path
import re
import sys

partuuid, resume_offset = sys.argv[1:3]
path = Path('/etc/default/limine')
text = path.read_text()

base_line = (
    f'KERNEL_CMDLINE[default]="cryptdevice=PARTUUID={partuuid}:root '
    'root=/dev/mapper/root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs"'
)
extra_line = (
    'KERNEL_CMDLINE[default]+="quiet splash '
    f'resume=/dev/mapper/root resume_offset={resume_offset} '
    'rtc_cmos.use_acpi_alarm=1 systemd.zram=0"'
)

text = re.sub(r'(?m)^KERNEL_CMDLINE\[default\]\+?=.*(?:\n|$)', '', text)

anchor = re.search(r'(?m)^ESP_PATH=.*$', text)
block = f'\n\n{base_line}\n{extra_line}'
if anchor:
    text = text[:anchor.end()] + block + text[anchor.end():]
else:
    text = block.lstrip('\n') + '\n' + text

text = re.sub(r'\n{3,}', '\n\n', text).rstrip() + '\n'

path.write_text(text)
PY

  ln -sfn /dev/null /etc/modprobe.d/nvidia-sleep.conf
  ln -sfn /dev/null /etc/modprobe.d/gsr-nvidia.conf

  materialize_file "${bootstrap_dir}/etc/modprobe.d/99-nvidia-suspend-workaround.conf" "/etc/modprobe.d/99-nvidia-suspend-workaround.conf"
  materialize_file "${bootstrap_dir}/etc/tmpfiles.d/no-dock-wakeup.conf" "/etc/tmpfiles.d/no-dock-wakeup.conf"
  materialize_file "${bootstrap_dir}/etc/tmpfiles.d/hibernate-image-size.conf" "/etc/tmpfiles.d/hibernate-image-size.conf"
  materialize_file "${bootstrap_dir}/etc/udev/rules.d/43-framework-dock-wakeup.rules" "/etc/udev/rules.d/43-framework-dock-wakeup.rules"
  materialize_file "${bootstrap_dir}/etc/systemd/logind.conf.d/90-lid-suspend-then-hibernate.conf" "/etc/systemd/logind.conf.d/90-lid-suspend-then-hibernate.conf"
  materialize_file "${bootstrap_dir}/etc/systemd/sleep.conf.d/90-suspend-then-hibernate.conf" "/etc/systemd/sleep.conf.d/90-suspend-then-hibernate.conf"
  materialize_file "${bootstrap_dir}/etc/systemd/zram-generator.conf" "/etc/systemd/zram-generator.conf"
  ensure_real_directory "/etc/systemd/system/systemd-suspend.service.d"
  ensure_real_directory "/etc/systemd/system/systemd-hibernate.service.d"
  ensure_real_directory "/etc/systemd/system/systemd-suspend-then-hibernate.service.d"
  materialize_file "${bootstrap_dir}/etc/systemd/system/systemd-suspend.service.d/90-freeze-user-sessions.conf" "/etc/systemd/system/systemd-suspend.service.d/90-freeze-user-sessions.conf"
  materialize_file "${bootstrap_dir}/etc/systemd/system/systemd-hibernate.service.d/90-freeze-user-sessions.conf" "/etc/systemd/system/systemd-hibernate.service.d/90-freeze-user-sessions.conf"
  materialize_file "${bootstrap_dir}/etc/systemd/system/systemd-suspend-then-hibernate.service.d/90-freeze-user-sessions.conf" "/etc/systemd/system/systemd-suspend-then-hibernate.service.d/90-freeze-user-sessions.conf"
  materialize_file "${bootstrap_dir}/etc/systemd/system/framework-pcloud-sleep.service" "/etc/systemd/system/framework-pcloud-sleep.service"
  materialize_file "${bootstrap_dir}/usr/local/libexec/framework-pcloud-sleep" "/usr/local/libexec/framework-pcloud-sleep" 755

  if [[ -f /boot/EFI/limine/limine_x64.efi ]]; then
    cp -f /boot/EFI/limine/limine_x64.efi /boot/EFI/BOOT/BOOTX64.EFI
    cp -f /boot/EFI/limine/limine_x64.efi /boot/EFI/arch-limine/BOOTX64.EFI
  fi

  udevadm control --reload
  udevadm trigger --subsystem-match=pci || true
  systemd-tmpfiles --create /etc/tmpfiles.d/no-dock-wakeup.conf /etc/tmpfiles.d/hibernate-image-size.conf
  systemctl daemon-reload
  systemctl enable framework-pcloud-sleep.service
  systemctl reload systemd-logind || true

  swapoff /dev/zram0 2>/dev/null || true
  systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true

  limine-mkinitcpio
  limine-update

  local limine_entry boot_order entry
  limine_entry=$(efibootmgr | sed -n 's/^Boot\([0-9A-F]\{4\}\)\* Limine$/\1/p' | head -n1)
  if [[ -n ${limine_entry} ]]; then
    boot_order=${limine_entry}
    while IFS= read -r entry; do
      entry=${entry#Boot}
      entry=${entry%%\**}
      if [[ ${entry} != "${limine_entry}" ]]; then
        boot_order+="${boot_order:+,}${entry}"
      fi
    done < <(efibootmgr | sed -n 's/^Boot\([0-9A-F]\{4\}\)\*.*/Boot\1/p')
    efibootmgr -o "${boot_order}" >/dev/null
  fi

  cat <<EOF
Framework power configuration applied.

Detected values:
  cryptdevice PARTUUID: ${partuuid}
  resume_offset: ${resume_offset}

Next steps:
  1. Reboot.
  2. Verify lid handling and hibernate with: systemctl hibernate
  3. If TPM auto-unlock prompts again, regenerate the Clevis TPM binding after boot artifacts settle.
EOF
}

main "$@"
