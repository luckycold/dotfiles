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

## Extras

Due to this not being able to be included locally, the following should be done if you want Goldwarden to work in applications like Obsidian:
```sudo  nvim /etc/security/pam_env.conf```
and include this on the bottom of that file:
```SSH_AUTH_SOCK DEFAULT=/home/$USER/.var/app/com.quexten.Goldwarden/data/ssh-auth-sock```

## Instructional Video
This is a useful video if you get lost:

https://www.youtube.com/watch?v=y6XCebnB9gs
