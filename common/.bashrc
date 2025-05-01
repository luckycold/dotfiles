# ~/.bashrc: executed by bash for non-login shells (universal Fedora/Pop_OS version)

# Source global definitions (cross-distro compatible)
[ -f /etc/bashrc ] && . /etc/bashrc          # Fedora/RHEL
[ -f /etc/bash.bashrc ] && . /etc/bash.bashrc # Debian/Ubuntu/Pop_OS

# User-specific PATH additions
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Only run in interactive shells
case $- in
    *i*) ;;
      *) return;;
esac

# History configuration (universal)
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

# Universal chroot prompt detection
if [ -n "$CHROOT_NAME" ]; then
    chroot_prompt="($CHROOT_NAME)"
elif [ -r /etc/chroot_name ]; then
    chroot_prompt="($(cat /etc/chroot_name))"
else
    chroot_prompt=""
fi

# Color prompt detection
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

if [ "$color_prompt" = yes ]; then
    PS1='${chroot_prompt}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${chroot_prompt}\u@\h:\w\$ '
fi

# Add SSH agent indicator to prompt
if [ "$color_prompt" = yes ]; then
    PS1='${chroot_prompt}${SSH_AGENT_ACTIVE:+\[\033[01;32m\]✓\[\033[00m\] }\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${chroot_prompt}${SSH_AGENT_ACTIVE:+✓ }\u@\h:\w\$ '
fi

# Window title for X terminals
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${chroot_prompt}\u@\h: \w\a\]$PS1"
    ;;
esac

# Color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Load aliases (Pop_OS style separation)
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Modular configuration (Fedora-style .bashrc.d)
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi

# Completion (cross-distro)
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

if command -v nvim >/dev/null 2>&1; then
    export EDITOR="nvim"
    export VISUAL="nvim"
fi


