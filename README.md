# My dotfiles

These are the dotfiles for my system

## Requirements

Make sure you have the these installed on your system

### Git
#### Fedora
```bash
sudo dnf install git
```
#### Debian
```bash
sudo apt install git
```

### Stow
#### Fedora
```bash
sudo dnf install stow
```
#### Debian
```bash
sudo apt install stow
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
#stow -t ~ work (or go with this if you want to get configs for work instead of personal)
```
The above is a bit of a departure from the instructional video for GNU stow. It's basically using the same idea but instead of using `stow .` you can switch between personal and work "profiles" to cleanly and quickly get up and running on any new computer install.

## Instructional Video
This is a useful video if you get lost:

https://www.youtube.com/watch?v=y6XCebnB9gs

test
