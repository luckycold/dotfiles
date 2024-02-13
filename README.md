# My dotfiles

These are the dotfiles for my system

## Requirements

Make sure you have the these installed on your system

### Git

```
sudo dnf install git
```

### Stow
```
sudo dnf install stow
```

## Installation

First, "check out" (the meaning you use in git not "take a look at") the dotfiles repo in your $HOME directory using git.

```
git clone https://github.com/luckycold/dotfiles.git
cd dotfiles
```

then use GNU stow to create symlinks

```
stow .
```