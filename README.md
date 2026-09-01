# My dotfiles

These are the dotfiles for my system

Canonical repository: [github.com/luckycold/dotfiles](https://github.com/luckycold/dotfiles).

## Requirements

### Recommended

#### For Linux
##### Arch
```bash
sudo pacman -S yay stow bitwarden-cli git github-cli ghostty neovim bitwarden lsof oath-toolkit solaar opencode
# yay -S ...
```
##### Debian/Ubuntu
```bash
sudo apt install stow git gh neovim ghostty lsof oathtool solaar opencode
```
##### Fedora
```bash
sudo dnf install stow git gh neovim ghostty bitwarden-cli lsof oathtool solaar
```

##### SteamOS

SteamOS is immutable. The SteamOS bootstrap uses per-user Flatpaks and
user-local CLI tools only; it does not invoke `pacman`, `sudo`, or
`steamos-readonly`. From Desktop Mode, clone this repository to `~/dotfiles`
and run:

```bash
./bootstrap/steamos/apply.sh
```

It installs Brave, Bitwarden, Proton Pass, Obsidian, ElectronMail, Zed,
Flatseal, and Solaar as per-user Flatpaks. Stow, Neovim, GitHub CLI, Lazygit,
Proton Pass CLI, and OpenCode are installed below `~/.local` (OpenCode uses
`~/.opencode`). Stow comes from Arch's prebuilt package and is extracted into
`~/.local`; no programs are compiled. A user-systemd timer checks for Flatpak
and CLI updates daily. Its `--update` path updates existing user-local tools
and Flatpaks without reapplying Stow packages or re-enabling services. Resilio
is intentionally not managed here. Beeper and Ghostty are not in Flathub, so
they are not installed on SteamOS.

##### Universal Extras
```bash
#Proton Pass CLI
curl -fsSL https://proton.me/download/pass-cli/install.sh | bash
#OpenCode
curl -fsSL https://opencode.ai/install | bash
```

###### Voxtype
Voxtype is recommended for local voice-to-text, but it is intentionally not
part of any default Stow profile. Opt in manually on Fedora/Nobara KDE systems
with the bootstrap script:

```bash
./bootstrap/voxtype-fedora-kde/apply.sh
```

The script installs the upstream RPM, Fedora runtime/build packages, and
upstream `dotool`; configures `ydotool` as a fallback; writes local-only
Voxtype config; sets hold-to-talk to `F9`; uses the `small.en` Whisper model;
and keeps output in real typing mode rather than clipboard/paste mode. Log out
and back in afterward if this is the first time adding the user to the `input`
group.

If `voxtype setup --download` leaves a too-small or corrupt `small.en` model,
replace it directly:

```bash
rm -f ~/.local/share/voxtype/models/ggml-small.en.bin
curl -L --fail -o ~/.local/share/voxtype/models/ggml-small.en.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin
systemctl --user restart voxtype
```

Verify with:

```bash
YDOTOOL_SOCKET=/run/ydotoold/socket voxtype setup check
voxtype config
systemctl --user status voxtype
```

##### Universal Flatpaks
```bash
flatpak install io.github.pwr_solaar.solaar
```

#### For Mac (Mostly for work)
```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew install stow git neovim iterm2 karabiner-elements aerospace bitwarden bitwarden-cli lsof opencode
```

##### Caveat for Mac
iTerm2's settings do not support symlinks. Stow the manually selected `mac`
package for its other items, then hard-link the ignored plist separately:

```bash
stow -t ~ common
stow -t ~ mac
ln ~/dotfiles/mac/Library/Preferences/com.googlecode.iterm2.plist ~/Library/Preferences/com.googlecode.iterm2.plist
```


### Minimum
Make sure you have the these installed on your system

#### For Linux
##### Arch
```bash
sudo pacman -S git stow
```
##### Debian
```bash
sudo apt install git stow
```
##### Fedora
```bash
sudo dnf install git stow
```

#### For Mac (Mostly for work)
```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew install stow git
```

## Installation

First, "check out" (the meaning you use in git not "take a look at") the dotfiles repo in your $HOME directory using git.

```bash
cd
git clone git@github.com:luckycold/dotfiles.git
cd dotfiles
```

then use GNU stow to create symlinks

```bash
stow -t ~ common
stow -t ~ personal

# or, on the external Work OS install:
stow -t ~ common
stow -t ~ work

# For systems with my exclusive use
# sudo stow -t / root
```

### Post-stow: Enable systemd user services

After stowing `common`, enable the Proton Pass service:

```bash
systemctl --user daemon-reload
systemctl --user enable --now proton-pass-cli-autologin.service
```

This single service handles:
- Auto-login to Proton Pass at startup
- SSH agent bootstrap
- Periodic health checks (every 5 minutes)
- Re-authentication after waking from sleep/hibernate

View logs with:

```bash
journalctl --user -u proton-pass-cli-autologin.service -f
journalctl --user -u proton-pass-cli-ssh-agent.service -f
```

The systemd login uses a Proton Pass agent token stored in the local keyring. Create one from an authenticated interactive `pass-cli` session with access to the vault containing SSH keys, store it, then restart the service.

The desktop notification includes an action to update the relevant keyring secret. Manual fallback:

```bash
~/Applications/proton-pass-web-login
```

The helper prompts for the vault, agent token name, and expiration, then stores the resulting token in the local keyring without printing it.

The above is a bit of a departure from the instructional video for GNU stow. It's basically using the same idea but instead of using `stow .` you can switch between personal and work "profiles" to cleanly and quickly get up and running on any new computer install.

`stow-profile` is home-directory only: it stows `common` plus one home profile and deliberately excludes `root` and any future `*-root` packages. Apply root-target packages explicitly with `sudo stow -t / ...`.

After switching profiles, refresh generated secret-backed configs:

```bash
init-env-secrets --all
```

## Repository layout

The repo is organised as Stow packages plus a few things Stow cannot manage cleanly:

- `common/` - everything shared across machines (shell, editors, terminals, Hyprland, AI tooling, systemd user units). Always stowed.
- `personal/`, `work/`, and `steamos/` - mutually exclusive home-directory machine/persona profiles. Stow exactly one alongside `common`.
- `common/.agents/AGENTS.md` and `common/.agents/skills/` - Luke's canonical cross-agent working agreement and personal [Agent Skills](https://agentskills.io). Codex, Cursor, and OpenCode discover the standard skill path directly; Claude uses relative compatibility links. Each harness keeps its required global-instruction entry point.
- `mac/` - macOS-only files (e.g. the iTerm2 plist, which must be hard-linked rather than symlinked).
- `root/` - system files that are safe to manage with `sudo stow -t / root` (target `/`, not `$HOME`).
- `bootstrap/` - host-specific setup that must be *copied* into place (not stowed) and is applied by `apply.sh` scripts (dual-boot, SDDM keyring, host audio).
- `.github/` - GitHub Actions (see Automation).

## Secret templates (`init-env-secrets`)

Configs that embed secrets are committed as `*.template.*` files with `{{pass://...}}` placeholders and are rendered into their real counterparts locally. The renderer is the `init-env-secrets` shell function (defined in `common/.bashrc.d/secrets.bash`).

- A template named `foo.template.json` renders to `foo.json`; `bar.template` renders to `bar`.
- `{{pass://...}}` placeholders are resolved with Proton Pass's `pass-cli` (not the unrelated `pass` command).
- Rendered outputs are gitignored and never committed.
- An interactive shell refreshes stale secrets automatically on startup and raises a desktop notification when something needs attention; `update-dotfiles` and `stow-profile` also offer to re-render.

Common commands:

```bash
init-env-secrets --all      # render everything non-interactively
init-env-secrets -l         # list templated secrets and their status
init-env-secrets -r         # interactively retry/select and re-render
```

Currently templated secrets include the Codex config, the Zed AI config, the mem0 `environment.d` key, the OpenCode mem0 token, the Linear MCP token, and the Kagi session token.

## Shell tooling

`common/.bashrc.d/` is split into focused modules. The main user-facing commands:

- `update-dotfiles` - pull the repo, re-render secrets, reload units; a background check also notifies when the repo is behind.
- `stow-profile` - select `personal`, `work`, `steamos`, or the manual `mac` package; restow, reload Hyprland/systemd, and re-render secrets.
- `proton-pass-login` / `netbird-login` - convenience auth helpers.

These commands default to a clone at `~/dotfiles`. Set `DOTFILES_DIR` to use a
different clone location consistently across update, notification, profile,
and secret tooling.

## AI coding tooling

This repo carries a fair amount of agent/LLM configuration:

- `common/.agents/AGENTS.md` - canonical cross-agent instructions and personal-skill routing. Codex, Claude, and OpenCode global instruction files resolve directly to it; Cursor uses an always-on user rule that loads it.
- `common/.agents/skills/` - personal Agent Skills transferred from Hermes (`direct-action-preferences`, `infrastructure-hygiene`, `proton-pass-cli`, `tasker-automation`, `truenas-custom-apps`) plus `personal-skill-maintenance`, which defines the shared self-learning workflow. Skills marked `author: Luke` may make targeted, evidence-backed updates to their canonical package after use.
- `common/.agents/private-context.template.md` - Proton Pass reference for private hostnames, domains, topology, and privileged connection values. `init-env-secrets` renders the ignored, mode-`0600` `~/.agents/private-context.md`; tracked skills use placeholders and load exact values only when needed.
- Luke-authored portable skills are also published in [`luckycold/agent-skills`](https://github.com/luckycold/agent-skills). `update-agent-skills` installs or refreshes the full collection through the `skills.sh` CLI for Codex, Claude Code, Cursor, and OpenCode. `update-dotfiles` runs that refresh after restowing the selected profile and before regenerating secret-backed templates.

- `common/.config/opencode/opencode.json` - the main [OpenCode](https://opencode.ai) config: default model, MCP servers (Kagi, GitLab, mem0, and several disabled-by-default work servers), and the `cursor-acp` provider.
- `common/.config/opencode/config.json` - a separate OpenCode config holding auth/utility plugins (Codex, Anthropic, Gemini, mem0, scheduler).
- `common/.codex/config.template.toml`, `common/.config/zed/settings.template.json` - Codex CLI and Zed AI configs (templated; see Secret templates).

### Personal skill self-learning

Hermes combines foreground `skill_manage` writes, a background review fork, usage metadata, and the Curator lifecycle. Only the foreground learning loop is portable across general Agent Skills implementations. This repo reproduces that part through always-on agent instructions and writable links to one canonical package: after a verified reusable workflow or correction, an agent updates only skills marked `author: Luke`.

The shared setup deliberately does not imitate Hermes' background usage counters, automatic stale/archive transitions, or LLM consolidation. Those require runtime-specific hooks and provenance state that standard `SKILL.md` consumers do not expose consistently. Git diffs provide the cross-agent review and rollback layer; skill changes remain uncommitted until explicitly requested.

Private operational context is kept out of the portable skill packages. Agents resolve approved exact values from the local Proton Pass-backed private context and must not quote or copy that rendered file into tracked documentation.

### Cursor models via open-cursor (`cursor-acp`)

The `cursor-acp` provider routes OpenCode through a Cursor subscription using the [`open-cursor`](https://github.com/Nomadcxx/opencode-cursor) plugin (an `@ai-sdk/openai-compatible` provider pointed at the local proxy on `127.0.0.1:32124`). Authenticate once with `cursor-agent login`.

The `cursor-acp` model catalog is committed directly in `opencode.json`. This keeps the Stow-managed config self-contained and avoids runtime-generated OpenCode config overlays.

To refresh the committed model list, use `open-cursor sync-models --variants --compact` as a source of truth, review the diff, then commit the updated `opencode.json`:

```bash
npx -y @rama_nigg/open-cursor@latest sync-models --variants --compact --config ~/.config/opencode/opencode.json --no-backup
opencode models | grep cursor-acp
```

## Other systemd user services

`common/.config/autostart/clevis-luks-udisks2.desktop` intentionally disables the distro `clevis-luks-udisks2` desktop autostart. Root disk auto-unlock is handled by the initramfs Clevis hook; the desktop helper is not needed here and fails on this setup because there is no `clevis` user.

## Automation

- **Renovate** (`.github/workflows/renovate.yml`, `.github/renovate-image`, `renovate.json`) keeps the self-hosted Renovate image pin up to date via a custom regex manager, surfacing updates through the dependency dashboard. The workflow authenticates with `GITHUB_TOKEN` (or optional `RENOVATE_TOKEN`) so it can run on GitHub Actions without a Forgejo leftover secret.

## Omarchy Setup Notes

This repo now leaves hibernation behavior to stock Omarchy. Use Omarchy's own setup and removal commands for hibernation rather than host-specific wrappers, `systemd` sleep drop-ins, or custom Limine `noresume` policy.

The remaining Omarchy-specific pieces are:

- `common/.config/hypr/*.lua` - Omarchy 4 Hyprland overrides (bindings, input, looknfeel, monitors)
- `personal/.config/hypr/autostart.lua` / `work/.config/hypr/autostart.lua` - persona autostart
- `bootstrap/dual-omarchy-boot/` - coordinates the personal/internal and work/external Omarchy boot menus
- `bootstrap/sddm-gnome-keyring/` - root-owned SDDM PAM config that unlocks the GNOME keyring on login
- `bootstrap/philosophia-audio/` - host-specific user-session bootstrap for disabling WirePlumber's headphone-removal media pause behavior on `philosophia`

Apply the personal Omarchy profile like this:

```bash
stow -t ~ common
stow -t ~ personal
sudo stow -t / root
sudo ./bootstrap/dual-omarchy-boot/apply.sh --role personal
sudo ./bootstrap/sddm-gnome-keyring/apply.sh
./bootstrap/philosophia-audio/apply.sh
```

For the external Work OS clone of this repo, apply the reciprocal boot role instead:

```bash
stow -t ~ common
stow -t ~ work
init-env-secrets --all
sudo ./bootstrap/dual-omarchy-boot/apply.sh --role work
```

The personal role keeps the internal Limine install as the firmware default and adds a `Work OS (external drive)` Limine menu entry that chainloads the external ESP directly by partition GUID, avoiding dependence on removable-drive UEFI NVRAM entries that firmware may delete. The work role adds a reciprocal `Personal OS (internal drive)` menu entry and sets `SKIP_UEFI=yes` in `/etc/default/limine` so Work OS updates rebuild the external ESP without trying to register or reorder UEFI NVRAM as the laptop default. When the peer ESP is visible, either role also re-enrolls the peer `limine.conf` checksum into that peer Limine binary and signs the main/fallback Limine loaders, preventing Secure Boot config-checksum panics after menu changes. Disk encryption remains owned by each OS's own boot artifacts after the handoff.

On Work OS, verify the user services that should stay enabled after stowing `common`:

```bash
systemctl --user is-active proton-pass-cli-autologin.service
systemctl --user is-active proton-pass-cli-ssh-agent.service
```

`agent-tts` and Kokoro units are intentionally not part of this repo anymore.

After moving an existing Work OS install from another laptop, also check for stale TPM-bound system credentials:

```bash
systemctl --failed
systemctl status systemd-tpm2-setup.service systemd-pcrproduct.service libvirtd.service
```

Failures from `systemd-tpm2-setup.service` or `systemd-pcrproduct.service` that mention TPM key integrity or `Failed to acquire anchor secret` are separate from the LUKS Clevis slot. They come from systemd measured-UKI/NvPCR state, not from dotfiles. The credential files live under `/var/lib/systemd/nvpcr/` and `/boot/loader/credentials/`, but the NvPCR indexes themselves are TPM-global (`0x1d10200`-`0x1d10202` for the stock systemd definitions). Do not undefine those TPM NV indexes casually on this dual-OS Framework because Personal OS sees the same TPM.

If `libvirtd.service` fails with `status=243/CREDENTIALS`, check whether `/var/lib/libvirt/secrets/secrets-encryption-key` decrypts on this machine and whether any libvirt secrets need preserving before regenerating it. If there are no real libvirt secrets to preserve, back up the old key and let systemd create a new encrypted key for this host:

```bash
sudo cp -a /var/lib/libvirt/secrets/secrets-encryption-key \
  /var/lib/libvirt/secrets/secrets-encryption-key.bak.$(date +%Y%m%d%H%M%S)
dd if=/dev/random bs=32 count=1 status=none | \
  sudo systemd-creds encrypt --name=secrets-encryption-key - \
  /var/lib/libvirt/secrets/secrets-encryption-key
sudo systemctl reset-failed libvirtd.service libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket
sudo systemctl restart libvirtd.service
```

After changing Secure Boot, Limine, UKI, or UEFI boot order, boot once through the final intended path before regenerating Clevis TPM bindings. PCR `1,7` bindings are intentionally strict and can be invalidated by boot-path changes. Once booted into the OS whose root disk should auto-unlock, check the slot and regenerate it if the binding was created on this same laptop TPM:

```bash
sudo clevis luks list -d <LUKS_DEVICE>
sudo clevis luks regen -q -d <LUKS_DEVICE> -s <CLEVIS_SLOT>
```

Use `/dev/nvme0n1p2` for the internal personal OS on this Framework install. On the external Work OS, identify the root LUKS partition from inside Work OS with `lsblk -f` first, then run the same commands there.

If a Clevis slot came from another laptop, do not expect `regen` to work because the old TPM cannot unseal it on this machine. Boot that OS once with the normal LUKS passphrase, then replace the foreign TPM binding from inside that OS:

```bash
sudo clevis luks list -d <LUKS_DEVICE>
sudo clevis luks unbind -d <LUKS_DEVICE> -s <OLD_CLEVIS_SLOT> -f
sudo clevis luks bind -d <LUKS_DEVICE> tpm2 '{"pcr_bank":"sha256","pcr_ids":"1,7"}'
sudo clevis luks list -d <LUKS_DEVICE>
```

Keep the normal passphrase slot. The Clevis slot should be an additional unlock path, not the only way back in.

If you are moving an already-tuned machine under Stow management instead of setting up a fresh install, use `--adopt` once for the profiles that already exist on disk:

```bash
stow --adopt -t ~ personal
sudo stow --adopt -t / root
```

What this covers:

- coordinate the dual-boot Limine menus
- install the SDDM PAM configuration that hooks GNOME keyring into login
- disable WirePlumber's MPRIS pause-on-output-removal behavior on `philosophia`

What is still a manual post-install step:

- if TPM/Clevis auto-unlock stops working after reinstall or after boot-chain changes, regenerate or rebind the TPM slot after the first successful reboot

Useful verification commands after reboot:

```bash
cat /proc/cmdline
swapon --show
cat /sys/power/state /sys/power/disk
busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate
systemctl hibernate
```

Important note for `root/` files:

- `root/` is now reserved for files that are safe to manage directly with Stow
- the SDDM PAM login file lives under `bootstrap/sddm-gnome-keyring/` so it is installed as a real root-owned file under `/etc/pam.d`
- SDDM PAM files are copied into `/etc` as real root-owned files because symlinks into `/home` are not reliable for login-time PAM configuration

## Instructional Video
This is a useful video if you get lost:

https://www.youtube.com/watch?v=y6XCebnB9gs
