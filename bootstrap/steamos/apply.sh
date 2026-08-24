#!/usr/bin/env bash
set -euo pipefail

mode=setup
case "${1:-}" in
  "")
    ;;
  --update)
    mode=update
    ;;
  *)
    printf 'Usage: %s [--update]\n' "$0" >&2
    exit 64
    ;;
esac

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
local_bin="$HOME/.local/bin"
local_share="$HOME/.local/share"

if [[ ! -r /etc/os-release ]] || ! grep -qx 'ID=steamos' /etc/os-release; then
  printf 'This bootstrap only supports SteamOS.\n' >&2
  exit 1
fi

for command in bsdtar curl flatpak git install perl python3 sha256sum tar; do
  command -v "$command" >/dev/null || {
    printf 'Required command is unavailable: %s\n' "$command" >&2
    exit 1
  }
done

mkdir -p "$local_bin" "$local_share"
export PATH="$local_bin:$HOME/.opencode/bin:$PATH"

install_stow() {
  local destination archive extraction
  destination="$local_share/arch-stow"
  archive=$(mktemp)
  extraction=$(mktemp -d)
  trap 'rm -f "$archive"; rm -rf "$extraction"' RETURN
  curl --fail --location --silent --show-error \
    https://archlinux.org/packages/extra/any/stow/download/ \
    --output "$archive"
  rm -rf "$destination"
  mkdir -p "$destination"
  bsdtar -xf "$archive" -C "$extraction"
  mv "$extraction/usr" "$destination/usr"
  trap - RETURN
  rm -f "$archive"
  rm -rf "$extraction"

  cat > "$local_bin/stow" <<EOF
#!/bin/sh
exec perl -I"$destination/usr/share/perl5/vendor_perl" "$destination/usr/bin/stow" "\$@"
EOF
  chmod 755 "$local_bin/stow"
}

release_asset() {
  local repository=$1 pattern=$2 release asset url digest version
  release=$(curl --fail --location --silent --show-error \
    "https://api.github.com/repos/$repository/releases/latest")
  asset=$(printf '%s' "$release" | python3 -c '
import json
import re
import sys

release = json.load(sys.stdin)
pattern = re.compile(sys.argv[1])
for asset in release["assets"]:
    if pattern.fullmatch(asset["name"]):
        digest = asset.get("digest")
        if not digest or not digest.startswith("sha256:"):
            raise SystemExit("Release asset has no SHA-256 digest.")
        print(asset["browser_download_url"])
        print(digest.removeprefix("sha256:"))
        print(release["tag_name"].removeprefix("v"))
        break
else:
    raise SystemExit("Expected release asset was not found.")
' "$pattern")
  mapfile -t values <<< "$asset"
  url=${values[0]}
  digest=${values[1]}
  version=${values[2]}

  RELEASE_ASSET_ARCHIVE=$(mktemp)
  RELEASE_ASSET_VERSION=$version
  curl --fail --location --silent --show-error "$url" --output "$RELEASE_ASSET_ARCHIVE"
  [[ "$(sha256sum "$RELEASE_ASSET_ARCHIVE" | cut -d ' ' -f 1)" == "$digest" ]] || {
    rm -f "$RELEASE_ASSET_ARCHIVE"
    printf 'SHA-256 verification failed for %s.\n' "$repository" >&2
    exit 1
  }
}

install_neovim() {
  local destination extraction
  release_asset neovim/neovim 'nvim-linux-x86_64\.tar\.gz'
  destination="$local_share/nvim-$RELEASE_ASSET_VERSION"

  if [[ ! -x "$destination/bin/nvim" ]]; then
    extraction=$(mktemp -d)
    tar -xzf "$RELEASE_ASSET_ARCHIVE" -C "$extraction"
    rm -rf "$destination"
    mv "$extraction/nvim-linux-x86_64" "$destination"
  fi
  rm -f "$RELEASE_ASSET_ARCHIVE"
  ln -sfn "$destination/bin/nvim" "$local_bin/nvim"
}

install_github_cli() {
  local destination extraction
  release_asset cli/cli 'gh_[0-9.]+_linux_amd64\.tar\.gz'
  destination="$local_share/gh-$RELEASE_ASSET_VERSION"

  if [[ ! -x "$destination/bin/gh" ]]; then
    extraction=$(mktemp -d)
    tar -xzf "$RELEASE_ASSET_ARCHIVE" -C "$extraction"
    rm -rf "$destination"
    mv "$extraction/gh_${RELEASE_ASSET_VERSION}_linux_amd64" "$destination"
  fi
  rm -f "$RELEASE_ASSET_ARCHIVE"
  ln -sfn "$destination/bin/gh" "$local_bin/gh"
}

install_lazygit() {
  local destination
  release_asset jesseduffield/lazygit 'lazygit_[0-9.]+_linux_x86_64\.tar\.gz'
  destination="$local_share/lazygit-$RELEASE_ASSET_VERSION"

  if [[ ! -x "$destination/lazygit" ]]; then
    rm -rf "$destination"
    mkdir -p "$destination"
    tar -xzf "$RELEASE_ASSET_ARCHIVE" -C "$destination" lazygit
  fi
  rm -f "$RELEASE_ASSET_ARCHIVE"
  ln -sfn "$destination/lazygit" "$local_bin/lazygit"
}

install_proton_pass_cli() {
  local manifest binary_info version url digest download actual
  manifest=$(curl --fail --location --silent --show-error \
    https://proton.me/download/pass-cli/versions.json)
  binary_info=$(printf '%s' "$manifest" | python3 -c '
import json
import sys

manifest = json.load(sys.stdin)
binary = manifest["passCliVersions"]["urls"]["linux"]["x86_64"]
print(manifest["passCliVersions"]["version"])
print(binary["url"])
print(binary["hash"])
')
  mapfile -t values <<< "$binary_info"
  version=${values[0]}
  url=${values[1]}
  digest=${values[2]}
  download=$(mktemp)
  curl --fail --location --silent --show-error "$url" --output "$download"
  actual=$(sha256sum "$download" | cut -d ' ' -f 1)
  [[ "$actual" == "$digest" ]] || {
    rm -f "$download"
    printf 'SHA-256 verification failed for Proton Pass CLI %s.\n' "$version" >&2
    exit 1
  }
  install -m 755 "$download" "$local_bin/pass-cli"
  rm -f "$download"
}

install_opencode() {
  local installer
  installer=$(mktemp)
  curl --fail --location --silent --show-error https://opencode.ai/install --output "$installer"
  bash "$installer" --no-modify-path
  rm -f "$installer"
}

install_flatpaks() {
  flatpak install --user --noninteractive flathub \
    com.bitwarden.desktop \
    com.brave.Browser \
    com.github.tchx84.Flatseal \
    com.github.vladimiry.ElectronMail \
    dev.zed.Zed \
    io.github.pwr_solaar.solaar \
    md.obsidian.Obsidian \
    me.proton.Pass
  flatpak update --user --noninteractive
}

install_stow
if [[ "$mode" == setup ]]; then
  "$local_bin/stow" --no-folding -n -t "$HOME" -d "$repo_root" common steamos
fi

install_neovim
install_github_cli
install_lazygit
install_proton_pass_cli
install_opencode

if [[ "$mode" == update ]]; then
  flatpak update --user --noninteractive
  printf 'SteamOS user-local tools and Flatpaks updated.\n'
  exit 0
fi

install_flatpaks
"$local_bin/stow" --no-folding -R -t "$HOME" -d "$repo_root" common steamos
systemctl --user daemon-reload
systemctl --user enable --now dotfiles-steamos-update.timer
systemctl --user enable --now proton-pass-cli-autologin.service

printf 'SteamOS setup complete. Log in to Proton Pass, then run init-env-secrets --all.\n'
