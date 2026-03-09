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
- `root/` for machine policy under `/etc` and `/usr/local/bin`

Overview of what had to be fixed to make this setup reliable:

- keep Hyprland on the AMD iGPU so the desktop session is not tied to the NVIDIA eGPU on boot, suspend, or wake
- remove the old `hypridle` DPMS-off behavior that could leave wakeup in a broken state
- disable NVIDIA's suspend video-memory preservation path, which was breaking suspend and hibernate with the eGPU attached
- disable Thunderbolt dock wake sources so suspend does not immediately wake back up
- wire hibernate to the real swapfile with the correct `resume=` and `resume_offset=` values
- disable zram so hibernate does not fail from memory pressure while building the image
- refresh Limine EFI binaries and boot order so fallback boot and hibernate resume use the same working path
- leave TPM/Clevis as a final machine-specific step, since measured-boot changes can require regenerating the unlock binding

Files involved in this setup:

- `personal/.config/uwsm/env` - pins Hyprland to the AMD iGPU with `AQ_DRM_DEVICES`
- `personal/.config/hypr/hypridle.conf` - keeps the safer lock/suspend behavior without the old DPMS-off listener
- `root/etc/modprobe.d/99-nvidia-suspend-workaround.conf` - disables NVIDIA video-memory preservation during suspend/hibernate
- `root/etc/modprobe.d/nvidia-sleep.conf` - should be linked to `/dev/null` by the bootstrap script to disable the vendor sleep override
- `root/etc/modprobe.d/gsr-nvidia.conf` - should be linked to `/dev/null` by the bootstrap script to disable the conflicting vendor override
- `root/etc/tmpfiles.d/no-dock-wakeup.conf` - disables the Thunderbolt dock PCI wake sources on boot
- `root/etc/tmpfiles.d/hibernate-image-size.conf` - forces the kernel to use the minimum hibernate image size
- `root/etc/systemd/logind.conf.d/90-lid-suspend-then-hibernate.conf` - sets lid close to `suspend-then-hibernate`
- `root/etc/systemd/sleep.conf.d/90-suspend-then-hibernate.conf` - sets the hibernate delay to 30 minutes
- `root/etc/systemd/zram-generator.conf` - disables zram so the swapfile is the only hibernate backing store
- `root/usr/local/bin/dotfiles-power-bootstrap` - fills in install-specific boot values, refreshes Limine, applies wake settings, disables zram live, and cleans up EFI boot order

Apply them like this:

```bash
stow -t ~ common
stow -t ~ personal
sudo stow -t / root
sudo /usr/local/bin/dotfiles-power-bootstrap
```

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
- force hibernate to use the swapfile instead of zram
- set lid-close to `suspend-then-hibernate` after 30 minutes
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

## Instructional Video
This is a useful video if you get lost:

https://www.youtube.com/watch?v=y6XCebnB9gs
