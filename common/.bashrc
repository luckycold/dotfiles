# General Terminal Setup

if [ ! -d "~/.local/share/omarchy" ]; then
  source ~/.local/share/omarchy/default/bash/rc
fi

# Source global definitions (cross-distro compatible)
[ -f /etc/bashrc ] && . /etc/bashrc           # Fedora/RHEL
[ -f /etc/bash.bashrc ] && . /etc/bash.bashrc # Debian/Ubuntu/Pop_OS

# User-specific PATH additions
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi

# Only run in interactive shells
case $- in
*i*) ;;
*) return ;;
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
xterm-color | *-256color) color_prompt=yes ;;
esac

if [ "$color_prompt" = yes ]; then
  PS1='${chroot_prompt}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${chroot_prompt}\u@\h:\w\$ '
fi

# Window title for X terminals
case "$TERM" in
xterm* | rxvt*)
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

# Display SSH Agent MOTD once
if [ -z "$_ssh_motd_shown" ] && [ "$SSH_AGENT_ACTIVE" = "1" ]; then
  echo -e "SSH Agent ✓"
  _ssh_motd_shown=1 # Flag for this shell instance
fi

# --- Dotfiles Management Functions ---

# Internal function to switch stow profiles
_switch_dotfiles_profile() {
  local target_profile="$1"
  local dotfiles_dir="$HOME/dotfiles" # Assume fixed location

  # Check if dotfiles directory exists
  if [ ! -d "$dotfiles_dir" ]; then
    echo "Error: Dotfiles directory '$dotfiles_dir' not found." >&2
    return 1
  fi

  echo "Switching profile in $dotfiles_dir..."
  pushd "$dotfiles_dir" >/dev/null || return 1

  # Unstow potential existing profiles (ignore errors)
  echo "(Attempting to unstow existing profiles...)"
  stow -D -t ~ personal >/dev/null 2>&1
  stow -D -t ~ work >/dev/null 2>&1

  # Stow the target profile or ensure common is stowed
  if [[ "$target_profile" =~ ^(personal|work)$ ]]; then
    if [ -d "$target_profile" ]; then
      echo "Stowing '$target_profile' profile..."
      if stow -t ~ "$target_profile"; then
        echo "Profile '$target_profile' stowed successfully."
      else
        echo "Error stowing profile '$target_profile'." >&2
      fi
    else
      echo "Error: Profile directory '$target_profile' not found." >&2
    fi
  elif [[ -z "$target_profile" || "$target_profile" == "skip" || "$target_profile" == "none" ]]; then
    echo "Ensuring only 'common' profile is stowed..."
    if [ -d "common" ]; then
      if stow -t ~ common; then
        echo "'common' profile stowed successfully."
      else
        echo "Error stowing 'common' profile." >&2
      fi
    else
      echo "Error: Profile directory 'common' not found." >&2
    fi
  else
    echo "Warning: Invalid target profile specified: '$target_profile'. No profile stowed." >&2
  fi

  popd >/dev/null
  echo "Profile switch complete."
}

# Function to manually switch profiles
stow-profile() {
  local selected_profile
  local confirmation
  echo "Which profile to stow? (personal/work/none) [Enter for none]"
  read -r selected_profile

  # Map empty input to "none"
  if [[ -z "$selected_profile" ]]; then
    selected_profile="none"
  fi

  if [[ "$selected_profile" == "none" ]]; then
    echo "This will ensure only the 'common' profile is active."
    echo "Continue? (Y/n)" # Indicate Yes is default
    read -r confirmation
    # Abort only if input starts with n or N (case-insensitive)
    if [[ "$confirmation" =~ ^[nN] ]]; then
      echo "Aborting profile switch."
      return 0
    fi
  fi

  _switch_dotfiles_profile "$selected_profile"
}

# The dotfiles update check has been moved to .bashrc.d/dotfiles_update_check
# which runs in the background and uses notifications instead of blocking terminal startup
# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
