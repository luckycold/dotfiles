# General Terminal Setup

if [ -d "$HOME/.local/share/omarchy" ]; then
  [ -f "$HOME/.local/share/omarchy/default/bash/rc" ] && source "$HOME/.local/share/omarchy/default/bash/rc" 2>/dev/null
fi

if [ -d "$HOME/.local/share/omarchy/bin/" ]; then
  PATH="$HOME/.local/share/omarchy/bin:$PATH"
fi

# Source global definitions (cross-distro compatible)
[ -f /etc/bashrc ] && . /etc/bashrc           # Fedora/RHEL
[ -f /etc/bash.bashrc ] && . /etc/bash.bashrc # Debian/Ubuntu/Pop_OS

# Only run in interactive shells
case $- in
*i*) ;;
*) return ;;
esac

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

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Keep system Python ahead of mise's managed interpreter so distro-packaged
# apps using /usr/bin/env python3 can still import Arch Python modules.
if compgen -G "$HOME/.local/share/mise/installs/python/*/bin" > /dev/null; then
  _opencode_new_path=""

  IFS=':'
  for _opencode_path_entry in $PATH; do
    case "$_opencode_path_entry" in
      "$HOME"/.local/share/mise/installs/python/*/bin) ;;
      *)
        if [ -n "$_opencode_new_path" ]; then
          _opencode_new_path="$_opencode_new_path:$_opencode_path_entry"
        else
          _opencode_new_path="$_opencode_path_entry"
        fi
        ;;
    esac
  done
  unset IFS

  PATH="$_opencode_new_path"
  unset _opencode_new_path
  unset _opencode_path_entry
fi

export WARP_ENABLE_WAYLAND=1
export WGPU_BACKEND=gl

# OpenClaw Completion
if [ -d "/home/lucky/.openclaw/completions" ]; then
  [ -f "/home/lucky/.openclaw/completions/openclaw.bash" ] && source "/home/lucky/.openclaw/completions/openclaw.bash"
fi
