# My dotfiles

These are the dotfiles for my system

Repository discussion and review happens on [Codeberg](https://codeberg.org/luckycold/dotfiles) only. Comments and pull requests opened elsewhere are not reviewed.

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
sudo dnf install stow git gh neovim ghostty bitwarden bw lsof oathtool solaar opencode
```

##### Universal Extras
```bash
#Proton Pass CLI
curl -fsSL https://proton.me/download/pass-cli/install.sh | bash
flatpak install io.github.pwr_solaar.solaar
```

#### For Mac (Mostly for work)
```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew install stow git neovim iterm2 karabiner-elements aerospace bitwarden bitwarden-cli lsof opencode
```

##### Caveat for Mac
iterm2's settings does not allow for symlinking, you'll need to hardlink the files instead.

```bash
ln -s ~/dotfiles/work/Library/Preferences/com.googlecode.iterm2.plist ~/Library/Preferences/com.googlecode.iterm2.plist
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
git clone https://codeberg.org/luckycold/dotfiles.git
cd dotfiles
```

then use GNU stow to create symlinks

```bash
stow -t ~ common
stow -t ~ personal
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

The systemd login uses a Proton Pass personal access token stored in the local keyring. Create one from an authenticated `pass-cli` session, store it, then restart the service.

The desktop notification includes an action to update the relevant keyring secret. Manual fallback:

```bash
~/Applications/proton-pass-web-login
pass-cli personal-access-token create --name "$(hostname)-systemd" --expiration 1y
secret-tool store --label='Proton Pass Personal Access Token' service proton-pass type pat
systemctl --user restart proton-pass-cli-autologin.service
```

The above is a bit of a departure from the instructional video for GNU stow. It's basically using the same idea but instead of using `stow .` you can switch between personal and work "profiles" to cleanly and quickly get up and running on any new computer install.

## Repository layout

The repo is organised as Stow packages plus a few things Stow cannot manage cleanly:

- `common/` - everything shared across machines (shell, editors, terminals, Hyprland, AI tooling, systemd user units). Always stowed.
- `personal/` and `work/` - mutually exclusive persona profiles. Stow exactly one alongside `common`.
- `mac/` - macOS-only files (e.g. the iTerm2 plist, which must be hard-linked rather than symlinked).
- `root/` - system files that are safe to manage with `sudo stow -t / root` (target `/`, not `$HOME`).
- `bootstrap/` - host-specific setup that must be *copied* into place (not symlinked) and is applied by `apply.sh` scripts. See the Framework Power section below.
- `.github/` and `.forgejo/` - CI for the GitHub mirror and the Codeberg/Forgejo canonical repo (see Automation).

## Secret templates (`init-env-secrets`)

Configs that embed secrets are committed as `*.template.*` files with `{{pass://...}}` placeholders and are rendered into their real counterparts locally. The renderer is the `init-env-secrets` shell function (defined in `common/.bashrc.d/secrets.bash`).

- A template named `foo.template.json` renders to `foo.json`; `bar.template` renders to `bar`.
- `{{pass://...}}` placeholders are resolved with Proton Pass's `pass-cli` (not the unrelated `pass` command).
- Rendered outputs are gitignored and never committed.
- An interactive shell refreshes stale secrets automatically on startup and raises a mako notification when something needs attention; `update-dotfiles` and `stow-profile` also offer to re-render.

Common commands:

```bash
init-env-secrets --all      # render everything non-interactively
init-env-secrets -l         # list templated secrets and their status
init-env-secrets -r         # interactively retry/select and re-render
```

Currently templated secrets include the Codex config, the Zed AI config, the MCPorter config, the mem0 `environment.d` key, the Kagi session token, and the WireGuard tunnels under `root/etc/wireguard/`.

## Shell tooling

`common/.bashrc.d/` is split into focused modules. The main user-facing commands:

- `update-dotfiles` - pull the repo, re-render secrets, reload units; a background check also notifies (via mako) when the repo is behind.
- `stow-profile` - switch between `personal`/`work` profiles, restow, reload Hyprland/systemd, and re-render secrets.
- `proton-pass-login` / `netbird-login` - convenience auth helpers.

## AI coding tooling

This repo carries a fair amount of agent/LLM configuration:

- `common/.config/opencode/opencode.json` - the main [OpenCode](https://opencode.ai) config: default model, MCP servers (Kagi, GitLab, mem0, and several disabled-by-default work servers), and the `cursor-acp` provider.
- `common/.config/opencode/config.json` - a separate OpenCode config holding auth/utility plugins (Codex, Anthropic, Gemini, mem0, scheduler). The version pins here are bumped automatically by Renovate.
- `common/.codex/config.template.toml`, `common/.config/zed/settings.template.json` - Codex CLI and Zed AI configs (templated; see Secret templates).
- `common/.mcporter/mcporter.json` - [MCPorter](https://github.com/steipete/mcporter) config for direct MCP auth/inspection (templated).

### Cursor models via open-cursor (`cursor-acp`)

The `cursor-acp` provider routes OpenCode through a Cursor subscription using the [`open-cursor`](https://github.com/Nomadcxx/opencode-cursor) plugin (an `@ai-sdk/openai-compatible` provider pointed at the local proxy on `127.0.0.1:32124`). Authenticate once with `cursor-agent login`.

The committed `opencode.json` only defines the provider scaffold (`name`/`npm`/`baseURL`) with an empty `models` map - the model list is owned entirely by the sync, not version-controlled. A systemd user timer regenerates the full Cursor catalog (with up-to-date pricing/variants for TokenSpeed) into `~/.config/opencode/open-cursor.generated.json`, which is gitignored and loaded by OpenCode via `OPENCODE_CONFIG` (set in `common/.config/environment.d/opencode.conf`). A missing file is tolerated; OpenCode simply lists no `cursor-acp` models until the first sync runs.

Refresh is `open-cursor sync-models --variants --compact`, run by `opencode-cursor-sync.timer` (shortly after login, then daily). On a fresh machine, trigger it once so the models appear immediately:

```bash
systemctl --user start opencode-cursor-sync.service   # refresh now
opencode models | grep cursor-acp                     # should list cursor-acp/* models
```

## Other systemd user services

Beyond the Proton Pass service documented above, `common` ships several user units (enable only the ones you want):

```bash
systemctl --user daemon-reload
systemctl --user enable --now opencode-cursor-sync.timer   # refresh Cursor model catalog (see above)
systemctl --user enable --now kokoro-fastapi.service       # local Kokoro TTS server (Docker)
systemctl --user enable --now agent-tts.service            # agent TTS frontend (needs kokoro-fastapi)
```

`kokoro-fastapi-gpu-switch.timer` is an optional helper that flips the Kokoro container between CPU/GPU images based on host state.

## Automation

- **Renovate** (`.forgejo/workflows/renovate.yml`, `renovate.json`) runs on Codeberg and keeps the OpenCode plugin version pins in `common/.config/opencode/config.json` up to date via custom regex managers, surfacing updates through the dependency dashboard.
- **OpenCode bot** (`.github/workflows/opencode.yml`) responds to `/oc` or `/opencode` comments on issues/PRs in the GitHub mirror, running OpenCode against the repo.

## Omarchy Framework Power Setup

For my personal Framework AMD + Thunderbolt dock + NVIDIA eGPU setup, the power-management changes are split between:

- `personal/` for user-session behavior
- `root/` for stow-safe machine policy under `/etc`
- `bootstrap/framework-power/` for the root-owned files that should be copied into `/etc`, not left as symlinks into `/home`
- `bootstrap/dual-omarchy-boot/` for coordinating the personal/internal and work/external Omarchy boot menus
- `bootstrap/sddm-gnome-keyring/` for the root-owned SDDM PAM config that unlocks the GNOME keyring on login

Scope note:

- the `personal/` changes here are still primarily aimed at this AMD Framework laptop, but the `uwsm` GPU pin is now conditional instead of hardcoded
- `personal/.config/uwsm/env` only exports `AQ_DRM_DEVICES` when both an AMD DRM card and an NVIDIA DRM card are present, and then picks the first AMD card it finds
- that makes the `personal/` side safer across other machines, but it is still not meant as a fully generic power profile for every AMD laptop
- `bootstrap/framework-power/` is fully personal to this specific Framework + Thunderbolt dock + NVIDIA eGPU setup and should be treated as host-specific
- `bootstrap/sddm-gnome-keyring/` is personal auth/session setup and should also be treated as a root-applied bootstrap, not a stowed profile
- `bootstrap/philosophia-audio/` is a host-specific user-session bootstrap for disabling WirePlumber's headphone-removal media pause behavior on `philosophia`

Overview of what had to be fixed to make this setup reliable:

- keep Hyprland on the AMD iGPU so the desktop session is not tied to the NVIDIA eGPU on boot, suspend, or wake
- remove the old `hypridle` DPMS-off behavior that could leave wakeup in a broken state
- disable NVIDIA's suspend video-memory preservation path, which was breaking suspend and hibernate with the eGPU attached
- disable Thunderbolt dock wake sources so suspend does not immediately wake back up
- use both `tmpfiles.d` and a udev rule so wakeup gets disabled both at boot and when dock/eGPU PCI devices hotplug later
- override NVIDIA's sleep-unit drop-ins so systemd freezes user sessions again during suspend, hibernate, and suspend-then-hibernate
- stop pCloud before sleep and start it again after resume so its FUSE mount does not strand user processes in unfreezable I/O
- wire hibernate to the real swapfile with the correct `resume=` and `resume_offset=` values
- disable zram so hibernate does not fail from memory pressure while building the image
- refresh Limine EFI binaries and boot order so fallback boot and hibernate resume use the same working path
- leave TPM/Clevis as a final machine-specific step, since measured-boot changes can require regenerating the unlock binding

Files involved in this setup:

- `personal/.config/uwsm/env` - conditionally pins Hyprland to the AMD DRM card when both AMD and NVIDIA GPUs are present
- `personal/.config/hypr/hypridle.conf` - keeps the safer lock/suspend behavior without the old DPMS-off listener
- `bootstrap/framework-power/apply.sh` - personal bootstrap for this machine that fills in install-specific boot values, copies real root-owned files into `/etc`, refreshes Limine, and applies wake settings
- `bootstrap/framework-power/etc/modprobe.d/99-nvidia-suspend-workaround.conf` - disables NVIDIA video-memory preservation during suspend/hibernate
- `bootstrap/framework-power/etc/tmpfiles.d/no-dock-wakeup.conf` - disables the Thunderbolt dock PCI wake sources on boot
- `bootstrap/framework-power/etc/udev/rules.d/43-framework-dock-wakeup.rules` - disables wake on the same PCI devices when the dock/eGPU chain appears later via hotplug or resume
- `bootstrap/framework-power/etc/systemd/system/systemd-suspend.service.d/90-freeze-user-sessions.conf` - overrides the NVIDIA vendor drop-in and freezes user sessions for suspend
- `bootstrap/framework-power/etc/systemd/system/systemd-hibernate.service.d/90-freeze-user-sessions.conf` - overrides the NVIDIA vendor drop-in and freezes user sessions for hibernate
- `bootstrap/framework-power/etc/systemd/system/systemd-suspend-then-hibernate.service.d/90-freeze-user-sessions.conf` - overrides the NVIDIA vendor drop-in and freezes user sessions for delayed hibernate
- `bootstrap/framework-power/etc/systemd/system/framework-pcloud-sleep.service` - stops pCloud before sleep and restarts it after resume
- `bootstrap/framework-power/usr/local/libexec/framework-pcloud-sleep` - helper invoked by the sleep service to control the user pCloud unit
- `bootstrap/framework-power/etc/tmpfiles.d/hibernate-image-size.conf` - forces the kernel to use the minimum hibernate image size
- `bootstrap/framework-power/etc/systemd/logind.conf.d/90-lid-suspend-then-hibernate.conf` - sets lid close to `suspend-then-hibernate`
- `bootstrap/framework-power/etc/systemd/sleep.conf.d/90-suspend-then-hibernate.conf` - sets the lid-close hibernate delay back to `30min`
- `bootstrap/framework-power/etc/systemd/zram-generator.conf` - disables zram so the swapfile is the only hibernate backing store

Apply them like this:

```bash
stow -t ~ common
stow -t ~ personal
sudo stow -t / root
sudo ./bootstrap/framework-power/apply.sh
sudo ./bootstrap/dual-omarchy-boot/apply.sh --role personal
sudo ./bootstrap/sddm-gnome-keyring/apply.sh
./bootstrap/philosophia-audio/apply.sh
```

For the external Work OS clone of this repo, apply the reciprocal boot role instead:

```bash
sudo ./bootstrap/dual-omarchy-boot/apply.sh --role work
```

The personal role keeps the internal Limine install as the firmware default, creates a persistent `Work OS` UEFI entry when the external ESP is present, and adds a `Work OS (external drive)` Limine menu entry that hands off to that firmware entry. The work role adds a reciprocal `Personal OS (internal drive)` menu entry and sets `SKIP_UEFI=yes` in `/etc/default/limine` so Work OS updates rebuild the external ESP without trying to register or reorder UEFI NVRAM as the laptop default. Disk encryption remains owned by each OS's own boot artifacts after the handoff.

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

- pin Hyprland to the AMD iGPU in `personal/.config/uwsm/env`
- keep `hypridle` from using the old DPMS-off path in `personal/.config/hypr/hypridle.conf`
- disable NVIDIA suspend integration that breaks suspend/hibernate with the eGPU
- disable Thunderbolt dock wakeups
- restore systemd's default user-session freezing during sleep operations
- quiesce pCloud so its FUSE mount does not block user-slice freezing
- force hibernate to use the swapfile instead of zram
- set lid-close to `suspend-then-hibernate` after the configured delay
- regenerate Limine boot artifacts and refresh fallback EFI binaries
- install the SDDM PAM configuration that hooks GNOME keyring into login
- disable WirePlumber's MPRIS pause-on-output-removal behavior on `philosophia`

What is still intentionally machine-specific and generated by the bootstrap script:

- the encrypted root `PARTUUID`
- the Btrfs swapfile `resume_offset`
- EFI boot-order cleanup for the current firmware

What is still a manual post-install step:

- if TPM/Clevis auto-unlock stops working after reinstall or after boot-chain changes, regenerate or rebind the TPM slot after the first successful reboot

Useful verification commands after reboot:

```bash
cat /proc/cmdline
swapon --show
systemctl hibernate
```

Important note for `root/` files:

- `root/` is now reserved for files that are safe to manage directly with Stow
- the power-management files for this specific Framework setup live under `bootstrap/framework-power/` instead
- the SDDM PAM login file lives under `bootstrap/sddm-gnome-keyring/` so it is installed as a real root-owned file under `/etc/pam.d`
- those files are copied into `/etc` as real root-owned files because symlinks into `/home` are not reliable for early boot, udev, modprobe, and `systemd-logind`
- treat the bootstrap scripts as the required final step for these root-owned files, not just optional helpers

## Instructional Video
This is a useful video if you get lost:

https://www.youtube.com/watch?v=y6XCebnB9gs
