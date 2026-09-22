# My dotfiles

These are the dotfiles for my system

Canonical repository: [github.com/luckycold/dotfiles](https://github.com/luckycold/dotfiles).

## Requirements

### Recommended

#### For Linux
##### Arch
```bash
sudo pacman -S yay stow bitwarden-cli git github-cli ghostty neovim bitwarden lsof oath-toolkit solaar opencode unison
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

##### Steam Controller on Hyprland (personal profile)

Install `steam` (which includes the `steam-devices` udev rules) and the AUR
package `lib32-extest` on Arch/Omarchy:

```bash
omarchy pkg add steam
omarchy pkg aur add lib32-extest
stow -n -t ~ personal
stow -t ~ personal
```

The personal profile launches Steam through `steam-launch`. That wrapper
unsets `GDK_SCALE` / `GDK_DPI_SCALE`, injects CEF
`--force-device-scale-factor` from the Steam window's Hyprland monitor (or
the focused monitor on first launch) times `STEAM_UI_SCALE_BIAS` (default 1),
still passes `-forcedesktopscaling` and writes `config.vdf` `ScaleFactor`
for older clients, and preloads `/usr/lib32/libextest.so`
when that library is installed. Extest converts Steam's X11 mouse/keyboard
emulation into uinput events that can control the Wayland desktop.

Current Steam ignores `STEAM_FORCE_DESKTOPUI_SCALING` and overwrites
`ScaleFactor` on startup. The CEF flag is patched into
`steamwebhelper_sniper_wrap.sh` after Steam's install verifier restores that
script, which is what actually sizes the store chrome to the compositor.
Without it the client keeps the last docked 1440p auto-scale (~0.95) and the
URL bar stays far smaller than Omarchy's 2x media widget.
Steam only applies that slider at start. `hypr/steam.lua` watches the
client window and runs `steam-launch --sync` when it lands on a different
monitor scale, which restarts just the Steam client. It also overrides
Omarchy's 1100x700 Steam box so the 2x UI is not packed into a 1x-era
window. Running `steam_app_*`
games block that restart so a match is not killed mid-session. Do not "fix"
Steam size with a global `GDK_SCALE`: that integer cannot be correct on
mixed-DPI, and Omarchy's monitor-scaling keybind will persist it onto every
GTK/X11 app. Launch Steam from the application menu or `steam-launch`.
Keep `lib32-extest` installed while this override is in use. No global
`LD_PRELOAD` or extra input-group membership are needed when
`steam-devices` grants the active user access to `/dev/uinput`.

This addresses desktop pointer input; game-specific Steam Input behavior still
needs to be tested per game. OpenPuck's built-in Lizard mode is also available
for basic desktop control independently of Steam.

The desktop file is based on Arch's Steam launcher (1.0.0.87); when its actions
change upstream, refresh this copy and keep `Exec=steam-launch`. To undo,
unstow/remove the personal `steam.desktop` override and restart Steam; the
system launcher then takes over.

Reference: https://github.com/Supreeeme/extest

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
#MCPorter (preferred when Homebrew is available)
brew install steipete/tap/mcporter
```

Without Homebrew, MCPorter can be installed with `npm install -g mcporter` when Node.js 24 or newer is available.

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

For a headless agent host, use `common` plus `agent` instead:

```bash
stow -n -t ~ common agent
stow -t ~ common agent
```

See [the agent profile](agent/README.md) for scoped-secret handling and the
desktop-service exceptions. Do not enable the desktop Proton auto-login helper
for this profile.

### Post-stow: Enable systemd user services

On desktop profiles only, after stowing `common`, enable the Proton Pass service.
Skip this section for the headless `agent` profile:

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

The above is a bit of a departure from the instructional video for GNU stow. It's basically using the same idea but instead of using `stow .` you can switch between `personal`, `work`, `steamos`, and `agent` "profiles" to cleanly and quickly get up and running on any new computer install.

`stow-profile` is home-directory only: it stows `common` plus one home profile and deliberately excludes `root` and any future `*-root` packages. Apply root-target packages explicitly with `sudo stow -t / ...`.

After switching desktop profiles, refresh generated secret-backed configs:

```bash
init-env-secrets --all
```

For the scoped `agent` profile, skip bulk rendering. Verify the existing scoped
Proton session with `pass-cli info`, set a short `PROTON_PASS_AGENT_REASON`, and
render only an explicitly authorized selector with `init-env-secrets <selector>`.
In non-interactive shells, load `common/.bashrc.d/secrets.bash` explicitly first.
The manual renderer is unchanged; do not use `--all` on scoped agent hosts.

## Repository layout

The repo is organised as Stow packages plus a few things Stow cannot manage cleanly:

- `common/` - everything shared across machines (shell, editors, terminals, Hyprland, AI tooling, systemd user units). Always stowed.
- `personal/`, `work/`, `steamos/`, and `agent/` - mutually exclusive home-directory machine/persona profiles. Stow exactly one alongside `common`; `agent` is for scoped, headless hosts.
- `common/.agents/AGENTS.md` - Luke's canonical cross-agent working agreement. Portable [Agent Skills](https://agentskills.io) live only in the external [`luckycold/agent-skills`](https://github.com/luckycold/agent-skills) repository and are installed into `~/.agents/skills`; no skills tree is tracked here. Each harness keeps its required global-instruction entry point.
- `mac/` - macOS-only files (e.g. the iTerm2 plist, which must be hard-linked rather than symlinked).
- `root/` - system files that are safe to manage with `sudo stow -t / root` (target `/`, not `$HOME`).
- `bootstrap/` - host-specific setup that must be *copied* into place (not stowed) and is applied by `apply.sh` scripts (dual-boot, SDDM keyring, host audio).
- `.github/` - GitHub Actions (see Automation).

## Secret templates (`init-env-secrets`)

Configs that embed secrets are committed as `*.template.*` files with `{{pass://...}}` placeholders and are rendered into their real counterparts locally. The renderer is the `init-env-secrets` shell function (defined in `common/.bashrc.d/secrets.bash`).

- A template named `foo.template.json` renders to `foo.json`; `bar.template` renders to `bar`.
- `{{pass://...}}` placeholders are resolved with Proton Pass's `pass-cli` (not the unrelated `pass` command).
- Rendered outputs are gitignored and never committed.
- An interactive shell checks stale secrets in a locked background startup job. Skills refresh in that job by default without delaying terminal startup; set `AGENT_SKILLS_AUTO_UPDATE=0` to disable it (see AI coding tooling). No-op runs stay silent; actual content updates and refresh failures raise desktop notifications. `update-dotfiles` and `stow-profile` also support secret refreshes.
- Scoped agents skip automatic bulk secret rendering at startup, during `update-dotfiles`, and when switching profiles. Use only authorized manual selectors; the manual `init-env-secrets` interface is unchanged.

Common commands:

```bash
init-env-secrets --all      # desktop profiles only: render everything non-interactively
init-env-secrets -l         # list templated secrets and their status
init-env-secrets -r         # interactively retry/select and re-render
```

Currently templated secrets include the Codex config, the Zed AI config, the mem0 `environment.d` key, the OpenCode mem0 token, the Linear MCP token, the Kagi session token, and the Music Assistant widget config.

## Shell tooling

`common/.bashrc.d/` is split into focused modules. The main user-facing commands:

- `update-dotfiles` - pull the repo, restow the profile, refresh allowed secrets, and reload units; a background check also notifies when the repo is behind. Skills refresh independently in the background shell-startup job, not during `update-dotfiles`. Scoped agents skip bulk secret rendering.
- `stow-profile` - select `personal`, `work`, `steamos`, `agent`, or the manual `mac` package; restow and reload Hyprland/systemd. Secret refresh is offered only when bulk rendering is allowed, never for the scoped `agent` profile.
- `proton-pass-login` / `netbird-login` - convenience auth helpers.

These commands default to a clone at `~/dotfiles`. Set `DOTFILES_DIR` to use a
different clone location consistently across update, notification, profile,
and secret tooling.

### Mise on immutable systems

On immutable or appliance-style systems such as SteamOS and TrueNAS, keep
developer runtimes out of the base operating system. Install mise and Node in
the current user's home directory instead:

```bash
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
mise install node@latest
mise reshim
export PATH="$HOME/.local/share/mise/shims:$PATH"
node --version
npm --version
```

After `common` is stowed, `.bashrc` adds the mise shim directory to `PATH` for
both interactive and non-interactive shells. The `update-agent-skills` helper
also falls back to `mise exec node@latest` and installs that contained Node
runtime when mise is present but Node is not yet installed:

```bash
source "${DOTFILES_DIR:-$HOME/dotfiles}/common/.bashrc.d/dotfiles_management.bash"
update-agent-skills
```

This setup writes only beneath `~/.local` and does not require Homebrew, a
system package manager, or changes to the immutable root filesystem.

## AI coding tooling

This repo carries a fair amount of agent/LLM configuration:

- `common/.agents/AGENTS.md` - canonical cross-agent instructions and personal-skill routing. Codex, Claude, and OpenCode global instruction files resolve directly to it; Cursor uses an always-on user rule that loads it.
- Luke-authored portable skills live only in [`luckycold/agent-skills`](https://github.com/luckycold/agent-skills), not a tracked dotfiles skills tree. `update-agent-skills` installs or refreshes the full collection through the `skills.sh` CLI into `~/.agents/skills` for Codex, Claude Code, Cursor, and OpenCode. GNU Stow excludes runtime skills and compatibility links (`common/.stow-local-ignore`).
- Automatic skills refresh runs in the locked background interactive-shell startup job by default, without delaying terminal startup. Set `AGENT_SKILLS_AUTO_UPDATE=0` to disable it. It executes `skills@latest` and installs content from the external skills repository. Automatic refresh has a 120-second timeout plus a 5-second kill grace and is skipped if neither `timeout` nor `gtimeout` is available. The manual `update-agent-skills` command remains unchanged and does not use that timeout. `update-dotfiles` does not directly run skill updates.
- `common/.agents/private-context.template.md` - Proton Pass reference for private hostnames, domains, topology, and privileged connection values. `init-env-secrets` renders the ignored, mode-`0600` `~/.agents/private-context.md`. Never commit the rendered private-context file. Portable skills use placeholders and load exact values only when needed.

- `common/.config/opencode/opencode.json` - the main [OpenCode](https://opencode.ai) config: automatic compaction/pruning settings and the single local MCPorter aggregate bridge. It defines no default model or custom provider.
- `common/.config/opencode/config.json` - a separate OpenCode config listing only `@mem0/opencode-plugin` and `opencode-scheduler`.
- `common/.codex/config.template.toml`, `common/.config/zed/settings.template.json` - Codex CLI and Zed AI configs (templated; see Secret templates), each connected only to MCPorter.
- `common/.config/music-assistant/config.template.json` - Omarchy Music Assistant widget and local-player config. `init-env-secrets` renders `~/.config/music-assistant/config.json`.
- `common/.mcporter/mcporter.template.json` - the canonical [MCPorter](https://github.com/openclaw/mcporter) MCP registry. It owns all upstream server definitions.
- `common/.local/bin/mcporter-mcp` - the aggregate stdio adapter used by Codex, OpenCode, Zed, and Hermes.

### Universal MCP aggregation

Every agent connects to one stdio server named `mcporter`. MCPorter then exposes the active upstream registry with namespaced tools. Individual agent configs must not carry direct upstream MCP definitions.

After stowing `common` on a desktop profile, render the registry and verify it.
Scoped agents must instead render only an authorized registry selector and use
only the upstream services approved for their session:

```bash
init-env-secrets --all
mcporter --config ~/.mcporter/mcporter.json config doctor
mcporter --config ~/.mcporter/mcporter.json list
```

The shared adapter exposes `kagi-ken,context7,gh_grep,gitlab,mem0` by default. Set `MCPORTER_SERVERS` locally to a comma-separated subset or to include work servers (Brokkr, Bridge, NetBox, Gravwell, and the others in the registry). OAuth state stays local under MCPorter's data directory and must not be committed.

### Personal skill self-learning

Hermes combines foreground `skill_manage` writes, a background review fork, usage metadata, and the Curator lifecycle. Only the foreground learning loop is portable across general Agent Skills implementations. This repo supports that part through always-on agent instructions; the writable skills are installed externally at `~/.agents/skills` from `luckycold/agent-skills`, not tracked in dotfiles. After a verified reusable workflow or correction, an agent updates only skills marked `author: Luke`.

The shared setup deliberately does not imitate Hermes' background usage counters, automatic stale/archive transitions, or LLM consolidation. Those require runtime-specific hooks and provenance state that standard `SKILL.md` consumers do not expose consistently. Review and version skill changes in the external `luckycold/agent-skills` repository, not in dotfiles; changes remain uncommitted until explicitly requested.

Private operational context is kept out of the portable skill packages. Agents resolve approved exact values from the local Proton Pass-backed private context and must not quote or copy that rendered file into tracked documentation.

## Other systemd user services

`common/.config/autostart/clevis-luks-udisks2.desktop` intentionally disables the distro `clevis-luks-udisks2` desktop autostart. Root disk auto-unlock is handled by the initramfs Clevis hook; the desktop helper is not needed here and fails on this setup because there is no `clevis` user.

## Automation

- **Renovate** (`.github/workflows/renovate.yml`, `.github/renovate-image`, `renovate.json`) keeps the self-hosted Renovate image pin up to date via a custom regex manager, surfacing updates through the dependency dashboard. The workflow authenticates with `GITHUB_TOKEN` (or optional `RENOVATE_TOKEN`) so it can run on GitHub Actions without a Forgejo leftover secret.

## Omarchy Setup Notes

This repo now leaves hibernation behavior to stock Omarchy. Use Omarchy's own setup and removal commands for hibernation rather than host-specific wrappers, `systemd` sleep drop-ins, or custom Limine `noresume` policy.

The remaining Omarchy-specific pieces are:

- `common/.config/hypr/*.lua` - Omarchy 4 Hyprland overrides (bindings, input, looknfeel, monitors)
- `personal/.config/hyprmoncfg/profiles/` - native hyprmoncfg profiles for the Framework laptop: `Docked` (Dell 4K/60 Hz through the dock, AOC 1440p/144 Hz through the eGPU) and `Stand alone`. Layouts match display identities rather than fixed connector numbers. After installing hyprmoncfg and stowing the personal profile, run `hyprmoncfg manage` to install its generated-config include, then `hyprmoncfg apply Docked` or `hyprmoncfg apply "Stand alone"`. Back up existing local profiles before stowing; generated active monitor files and plugin code are not tracked. After changing a layout, save it with hyprmoncfg and sync its profile files back here.
- `personal/.config/wluma/config.toml` - wluma auto-brightness for the Framework ALS and docked DDC monitors. There is no pacman, Flatpak, or AUR `-bin` package; install extra `iio-sensor-proxy`, add `github:max-baz/wluma` to mise, install `root/etc/udev/rules.d/90-wluma-backlight.rules`, and enable `wluma.service`. The config only disables gamma so Omarchy nightlight keeps hyprsunset. wluma learns from Omarchy brightness keys and hyprmoncfg sliders; it does not start adjusting until those have been used a few times in different lighting. `personal/.local/bin/wluma-laptop-curve` is the hyprmoncfg `exec` on Docked and Stand alone: it points `~/.local/state/wluma/eDP-1.yaml` at a docked or standalone curve file so the laptop panel learns separately.
- `personal/.config/hypr/autostart.lua` / `work/.config/hypr/autostart.lua` - persona autostart
- `bootstrap/dual-omarchy-boot/` - coordinates the personal/internal and work/external Omarchy boot menus, reapplies the black-and-white Limine palette after `limine-update`, and documents the dual-key Secure Boot split
- `root/etc/sddm.conf.d/zz-where-is-my-sddm.conf` and `root/usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf.user` - SDDM theme selection, no autologin, and the matching black-and-white login colors
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

For the external Work OS clone of this repo, apply the reciprocal boot role and the same system theme files:

```bash
stow -t ~ common
stow -t ~ work
init-env-secrets --all
sudo stow -t / root
sudo ./bootstrap/sddm-gnome-keyring/apply.sh
sudo ./bootstrap/dual-omarchy-boot/apply.sh --role work
```

Work also needs the `where-is-my-sddm-theme-git` theme package so `theme.conf.user` has a theme to overlay. Do not pass `--update-firmware-entries` or `--repair-peer` on a proven laptop: those flags rewrite NVRAM or the peer ESP.

The personal role leaves firmware BootOrder alone and adds a `Work OS (external drive)` Limine menu entry that chainloads the external ESP by partition GUID. The working firmware path is the internal disk's own EFI Hard Drive / fallback loader, not a named `Limine` NVRAM entry. The work role adds a reciprocal `Personal OS (internal drive)` menu entry and sets `SKIP_UEFI=yes` in `/etc/default/limine` so Work updates rebuild the external ESP without registering or reordering UEFI NVRAM. Both roles install `/etc/limine-theme.conf` and hook `87-limine-theme`, which rewrites the Limine header to the black-and-white palette after every `limine-update` (including `omarchy-refresh-limine`) and before config checksum enrollment.

Secure Boot is split by design:

- Each OS has its own sbctl keyset and signs only its own ESP (Limine, fallback, UKIs).
- Personal owns the firmware-enrolled PK/KEK. Only Personal may write firmware `db`.
- Firmware `db` must contain both public `db` certificates plus the vendor/Microsoft builtins. Copy only the peer public `db.pem` into Personal's `/var/lib/sbctl/keys/custom/db/`, then enroll from Personal with `sbctl enroll-keys --partial db --custom --microsoft --firmware-builtin`. If firmware `db` is immutable, use the documented `--ignore-immutable` plus `chattr` path on **db only**. Never enroll Work PK/KEK and never use `sbctl enroll-keys --yes-this-might-brick-my-machine`.
- Do not change `BootOrder` or set `BootNext` to pick an OS. That is how PCR 1 bindings go stale. Use the firmware boot menu or the Limine GUID chainload entries.
- Disk encryption stays on each OS's own LUKS header after the handoff. The working Clevis policy here is PCR `7` (Secure Boot state). PCR `1,7` is stricter and breaks across firmware-variable changes and hibernation resume. With the Thunderbolt dock, eGPU, and NVMe enclosure attached, PCR `7` alternates between boots as option-ROM `db` authority events come and go, so each OS keeps one Clevis PCR `7` slot per observed state (plus the passphrase slot) instead of replacing a slot that only fails in the other state.

### Sharing state between Personal and Work

Some state is not in this repo but should match on both installs: third-party Omarchy plugin checkouts, Bluetooth pairings, and fingerprint stubs. Sync them with Unison (official `extra`), by hand, whenever the other OS's disk is unlocked and mounted. There is deliberately no unit, timer, or wrapper for this.

1. Unlock and mount the peer disk (the file manager does this; Omarchy mounts the top-level Btrfs volume under `/run/media/<user>/<uuid>/`). Set two paths for the commands below:

```bash
PEER_HOME=/run/media/$USER/<uuid>/@home/$USER
PEER_ROOT=/run/media/$USER/<uuid>/@
```

2. Omarchy plugins. Each plugin under `~/.config/omarchy/plugins/` is a git clone. Unison copies `.git` too, so a plugin that is checked out on a branch on one side and freshly cloned on the other will have the clone's `main` win and lose the branch. Before syncing, commit or push any plugin work in progress, and check out the same branch on both sides. `shell.json` stays per OS (bar layout and idle differ).

```bash
unison -ui text -batch -auto -prefer newer \
  ~/.config/omarchy/plugins "$PEER_HOME/.config/omarchy/plugins"
```

Missing plugins can instead be installed onto the peer home with `HOME="$PEER_HOME" omarchy plugin add <git-url> --yes` (never `--enable` from the other OS).

3. Bluetooth. Both installs present the same adapter MAC, so pairings are interchangeable. A device keeps one link key per host, so pair on one OS, then sync; re-pairing on one side breaks the other until the next sync.

```bash
sudo unison -ui text -batch -auto -prefer newer -owner -group -times \
  /var/lib/bluetooth "$PEER_ROOT/var/lib/bluetooth"
sudo systemctl restart bluetooth
```

4. Fingerprints. The Goodix sensor is match-on-chip: the templates live on the sensor and `/var/lib/fprint/<user>/goodixmoc/<sensor-serial>/<finger>` is a stub pointing at the on-chip slot. Enroll once (`omarchy setup security fingerprint`), then sync the stubs. Do not `fprintd-delete` or re-enroll "to start clean" on one OS; that clears the slot both sides reference. Stubs for old sensor serials are harmless.

```bash
sudo unison -ui text -batch -auto -prefer newer -owner -group -times \
  /var/lib/fprint "$PEER_ROOT/var/lib/fprint"
fprintd-list "$USER"
```

`-prefer newer` resolves the first-run conflicts in favor of the most recent copy, which is the right answer for pairings and enrollments. Later runs use Unison's archive and only propagate real changes.

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

After changing Secure Boot, Limine, UKI, or UEFI boot order, boot once through the final intended path before regenerating Clevis TPM bindings. The working policy on this laptop is PCR `7`. Once booted into the OS whose root disk should auto-unlock, check the slot and regenerate it if the binding was created on this same laptop TPM:

```bash
sudo clevis luks list -d <LUKS_DEVICE>
sudo clevis luks regen -q -d <LUKS_DEVICE> -s <CLEVIS_SLOT>
```

Use `/dev/nvme0n1p2` for the internal personal OS on this Framework install. On the external Work OS, identify the root LUKS partition from inside Work OS with `lsblk -f` first, then run the same commands there.

If a Clevis slot came from another laptop, or was bound to PCR `1,7` on an old named firmware entry, do not expect `regen` to work after the boot path changed. Boot that OS once with the normal LUKS passphrase, then replace the foreign or stale TPM binding from inside that OS:

```bash
sudo clevis luks list -d <LUKS_DEVICE>
sudo clevis luks unbind -d <LUKS_DEVICE> -s <OLD_CLEVIS_SLOT> -f
sudo clevis luks bind -d <LUKS_DEVICE> tpm2 '{"pcr_bank":"sha256","pcr_ids":"7"}'
sudo clevis luks list -d <LUKS_DEVICE>
```

Keep the normal passphrase slot. The Clevis slot should be an additional unlock path, not the only way back in.

If you are moving an already-tuned machine under Stow management instead of setting up a fresh install, use `--adopt` once for the profiles that already exist on disk:

```bash
stow --adopt -t ~ personal
sudo stow --adopt -t / root
```

What this covers:

- coordinate the dual-boot Limine menus and black-and-white Limine palette
- stow the SDDM theme overlay and disable autologin after TPM disk unlock
- install the SDDM PAM configuration that hooks GNOME keyring into login
- keep Work off firmware NVRAM (`SKIP_UEFI=yes`) while Personal owns enrolled Secure Boot keys
- disable WirePlumber's MPRIS pause-on-output-removal behavior on `philosophia`

What is still a manual post-install step:

- if TPM/Clevis auto-unlock stops working after reinstall or after boot-chain changes, regenerate or rebind the TPM slot after the first successful reboot
- if Work's public `db` certificate is new, copy only that public cert to Personal and enroll firmware `db` from Personal

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
- the SDDM theme overlay and autologin override live under `root/` so both personas pick them up with `sudo stow -t / root`
- the SDDM PAM login file lives under `bootstrap/sddm-gnome-keyring/` so it is installed as a real root-owned file under `/etc/pam.d`
- SDDM PAM files are copied into `/etc` as real root-owned files because symlinks into `/home` are not reliable for login-time PAM configuration

## Instructional Video
This is a useful video if you get lost:

https://www.youtube.com/watch?v=y6XCebnB9gs
