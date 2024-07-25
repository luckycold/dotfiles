# My dotfiles

These are the dotfiles for my system

## Requirements

Make sure you have the these installed on your system

### Git

```bash
sudo dnf install git
```

### Stow
```bash
sudo dnf install stow
```

## Installation

First, "check out" (the meaning you use in git not "take a look at") the dotfiles repo in your $HOME directory using git.

```bash
git clone https://github.com/luckycold/dotfiles.git
cd dotfiles
```

then use GNU stow to create symlinks

```bash
stow .
```

## Instructional Video
This is a useful video if you get lost:

https://www.youtube.com/watch?v=y6XCebnB9gs
