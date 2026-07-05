#!/usr/bin/env bash
set -euo pipefail

voxtype_version="0.7.5"
rpm_name="voxtype-${voxtype_version}-1.x86_64.rpm"
rpm_url="https://github.com/peteonrails/voxtype/releases/download/v${voxtype_version}/${rpm_name}"
ydotool_socket="/run/ydotoold/socket"
dotool_source_dir="/tmp/dotool-src"

log() {
  printf 'voxtype-fedora-kde: %s\n' "$*"
}

die() {
  log "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

backup_if_real_file() {
  local path="$1"

  if [[ -e "$path" && ! -L "$path" ]]; then
    cp -a "$path" "${path}.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

write_user_file() {
  local path="$1"
  local mode="$2"

  mkdir -p "$(dirname "$path")"
  backup_if_real_file "$path"
  rm -f "$path"
  install -m "$mode" /dev/stdin "$path"
}

require_command curl
require_command dnf
require_command getent
require_command rpm
require_command sudo
require_command systemctl

if [[ -r /etc/os-release ]]; then
  # shellcheck source=/dev/null
  source /etc/os-release
else
  die "cannot read /etc/os-release"
fi

case "${ID:-}" in
  fedora|nobara) ;;
  *) die "this opt-in setup is only intended for Fedora/Nobara KDE systems" ;;
esac

case "${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}" in
  *KDE*|*Plasma*|*plasma*) ;;
  *) log "current desktop does not look like KDE/Plasma; continuing because this script was explicitly run" ;;
esac

sudo dnf install -y \
  gcc \
  git \
  golang \
  libnotify \
  libxkbcommon-devel \
  pipewire-alsa \
  playerctl \
  scdoc \
  wl-clipboard \
  wtype \
  ydotool

if ! rpm -q voxtype >/dev/null 2>&1; then
  curl -L -o "/tmp/${rpm_name}" "$rpm_url"
  sudo dnf install -y "/tmp/${rpm_name}"
fi

sudo usermod -aG input "$USER"

rm -rf "$dotool_source_dir"
git clone --depth 1 https://git.sr.ht/~geb/dotool "$dotool_source_dir"
(
  cd "$dotool_source_dir"
  ./build.sh
  sudo ./build.sh install
)
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=misc --attr-match=name=uinput || true

input_gid="$(getent group input | awk -F: '{ print $3 }')"
[[ -n "$input_gid" ]] || die "could not resolve input group gid"

if [[ -L /etc/systemd/system/ydotool.service.d ]]; then
  sudo rm -f /etc/systemd/system/ydotool.service.d
fi

sudo mkdir -p /etc/systemd/system/ydotool.service.d
printf '%s\n' \
  '[Service]' \
  'RuntimeDirectory=ydotoold' \
  'ExecStart=' \
  "ExecStart=/usr/bin/ydotoold --socket-path=${ydotool_socket} --socket-perm=0660 --socket-own=0:${input_gid}" \
  | sudo tee /etc/systemd/system/ydotool.service.d/10-fedora-kde-socket.conf >/dev/null

write_user_file "$HOME/.config/systemd/user/voxtype.service.d/10-ydotool.conf" 0644 <<EOF
[Service]
Environment=YDOTOOL_SOCKET=${ydotool_socket}
EOF

write_user_file "$HOME/.config/voxtype/config.toml" 0644 <<'EOF'
# Voxtype defaults for Fedora KDE/Plasma systems.

state_file = "auto"

[hotkey]
key = "F9"
modifiers = []
mode = "push_to_talk"
enabled = true

[audio]
device = "default"
sample_rate = 16000
max_duration_secs = 60

[whisper]
model = "small.en"
language = "en"
translate = false

[output]
mode = "type"
fallback_to_clipboard = true
driver_order = ["dotool", "ydotool", "clipboard"]
dotool_xkb_layout = "us"
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now ydotool.service

voxtype setup --download --model small.en

systemctl --user daemon-reload
systemctl --user enable --now voxtype.service
systemctl --user restart voxtype.service

log "installed Voxtype Fedora/KDE opt-in setup"
log "log out and back in if this is the first time adding $USER to the input group"
