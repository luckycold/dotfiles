# My dotfiles

These are the dotfiles for my system

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
git clone https://github.com/luckycold/dotfiles.git
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
```

The above is a bit of a departure from the instructional video for GNU stow. It's basically using the same idea but instead of using `stow .` you can switch between personal and work "profiles" to cleanly and quickly get up and running on any new computer install.

## Omarchy Framework Power Setup

For my personal Framework AMD + Thunderbolt dock + NVIDIA eGPU setup, the power-management changes are split between:

- `personal/` for user-session behavior
- `root/` for stow-safe machine policy under `/etc`
- `bootstrap/framework-power/` for the root-owned files that should be copied into `/etc`, not left as symlinks into `/home`

Scope note:

- the `personal/` changes here are still primarily aimed at this AMD Framework laptop, but the `uwsm` GPU pin is now conditional instead of hardcoded
- `personal/.config/uwsm/env` only exports `AQ_DRM_DEVICES` when both an AMD DRM card and an NVIDIA DRM card are present, and then picks the first AMD card it finds
- that makes the `personal/` side safer across other machines, but it is still not meant as a fully generic power profile for every AMD laptop
- `bootstrap/framework-power/` is fully personal to this specific Framework + Thunderbolt dock + NVIDIA eGPU setup and should be treated as host-specific

Overview of what had to be fixed to make this setup reliable:

- keep Hyprland on the AMD iGPU so the desktop session is not tied to the NVIDIA eGPU on boot, suspend, or wake
- remove the old `hypridle` DPMS-off behavior that could leave wakeup in a broken state
- disable NVIDIA's suspend video-memory preservation path, which was breaking suspend and hibernate with the eGPU attached
- disable Thunderbolt dock wake sources so suspend does not immediately wake back up
- use both `tmpfiles.d` and a udev rule so wakeup gets disabled both at boot and when dock/eGPU PCI devices hotplug later
- override NVIDIA's sleep-unit drop-ins so systemd freezes user sessions again during suspend, hibernate, and suspend-then-hibernate
- wire hibernate to the real swapfile with the correct `resume=` and `resume_offset=` values
- disable zram so hibernate does not fail from memory pressure while building the image
- refresh Limine EFI binaries and boot order so fallback boot and hibernate resume use the same working path
- leave TPM/Clevis as a final machine-specific step, since measured-boot changes can require regenerating the unlock binding

Files involved in this setup:

- `personal/.config/uwsm/env` - conditionally pins Hyprland to the AMD DRM card when both AMD and NVIDIA GPUs are present
- `personal/.config/hypr/hypridle.conf` - keeps the safer lock/suspend behavior without the old DPMS-off listener
- `personal/.local/bin/hypr-resume-monitor-recover` - watches for resume events and reinitializes the dock-facing displays on this machine
- `personal/.config/systemd/user/hypr-resume-monitor-recover.service` - keeps the resume monitor-recovery hook running in the user session
- `bootstrap/framework-power/apply.sh` - personal bootstrap for this machine that fills in install-specific boot values, copies real root-owned files into `/etc`, refreshes Limine, and applies wake settings
- `bootstrap/framework-power/etc/modprobe.d/99-nvidia-suspend-workaround.conf` - disables NVIDIA video-memory preservation during suspend/hibernate
- `bootstrap/framework-power/etc/tmpfiles.d/no-dock-wakeup.conf` - disables the Thunderbolt dock PCI wake sources on boot
- `bootstrap/framework-power/etc/udev/rules.d/43-framework-dock-wakeup.rules` - disables wake on the same PCI devices when the dock/eGPU chain appears later via hotplug or resume
- `bootstrap/framework-power/etc/systemd/system/systemd-suspend.service.d/90-freeze-user-sessions.conf` - overrides the NVIDIA vendor drop-in and freezes user sessions for suspend
- `bootstrap/framework-power/etc/systemd/system/systemd-hibernate.service.d/90-freeze-user-sessions.conf` - overrides the NVIDIA vendor drop-in and freezes user sessions for hibernate
- `bootstrap/framework-power/etc/systemd/system/systemd-suspend-then-hibernate.service.d/90-freeze-user-sessions.conf` - overrides the NVIDIA vendor drop-in and freezes user sessions for delayed hibernate
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
```

If you are moving an already-tuned machine under Stow management instead of setting up a fresh install, use `--adopt` once for the profiles that already exist on disk:

```bash
stow --adopt -t ~ personal
sudo stow --adopt -t / root
```

What this covers:

- pin Hyprland to the AMD iGPU in `personal/.config/uwsm/env`
- keep `hypridle` from using the old DPMS-off path in `personal/.config/hypr/hypridle.conf`
- run a user-level monitor recovery hook after resume so the docked displays are reinitialized when the display chain comes back in a bad state
- disable NVIDIA suspend integration that breaks suspend/hibernate with the eGPU
- disable Thunderbolt dock wakeups
- restore systemd's default user-session freezing during sleep operations
- force hibernate to use the swapfile instead of zram
- set lid-close to `suspend-then-hibernate` after the configured delay
- regenerate Limine boot artifacts and refresh fallback EFI binaries

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
- those files are copied into `/etc` as real root-owned files because symlinks into `/home` are not reliable for early boot, udev, modprobe, and `systemd-logind`
- treat `sudo ./bootstrap/framework-power/apply.sh` as the required final step for this machine, not just an optional helper

## Instructional Video
This is a useful video if you get lost:

https://www.youtube.com/watch?v=y6XCebnB9gs
