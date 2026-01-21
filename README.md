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
# stow -t / root
```

### Post-stow: Enable systemd user services

After stowing `common`, enable the Proton Pass auto-login service:

```bash
systemctl --user daemon-reload
systemctl --user enable --now proton-pass-cli-autologin.service
```

This service logs into Proton Pass at login and starts the SSH agent. View logs with:

```bash
journalctl --user -u proton-pass-cli-autologin.service
```

The above is a bit of a departure from the instructional video for GNU stow. It's basically using the same idea but instead of using `stow .` you can switch between personal and work "profiles" to cleanly and quickly get up and running on any new computer install.

## Instructional Video
This is a useful video if you get lost:

https://www.youtube.com/watch?v=y6XCebnB9gs
