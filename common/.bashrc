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

if [ ! -d "$HOME/.local/share/omarchy" ]; then
  alias c=opencode
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

# Keep system/devenv interpreters ahead of mise's managed ones.
# - Python: distro apps using /usr/bin/env python3 still see Arch modules.
# - Node: brokkr devenv (nodejs_24) must not lose to global mise node 25.
if compgen -G "$HOME/.local/share/mise/installs/python/*/bin" > /dev/null ||
  compgen -G "$HOME/.local/share/mise/installs/node/*/bin" > /dev/null; then
  _mise_demote_path=""

  IFS=':'
  for _mise_path_entry in $PATH; do
    case "$_mise_path_entry" in
      "$HOME"/.local/share/mise/installs/python/*/bin) ;;
      "$HOME"/.local/share/mise/installs/node/*/bin) ;;
      *)
        if [ -n "$_mise_demote_path" ]; then
          _mise_demote_path="$_mise_demote_path:$_mise_path_entry"
        else
          _mise_demote_path="$_mise_path_entry"
        fi
        ;;
    esac
  done
  unset IFS

  PATH="$_mise_demote_path"
  unset _mise_demote_path
  unset _mise_path_entry
fi

export WARP_ENABLE_WAYLAND=1
export WGPU_BACKEND=gl

# OpenClaw Completion
if [ -d "/home/lucky/.openclaw/completions" ]; then
  [ -f "/home/lucky/.openclaw/completions/openclaw.bash" ] && source "/home/lucky/.openclaw/completions/openclaw.bash"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
[[ -r "$HOME/.grok/completions/bash/grok.bash" ]] && source "$HOME/.grok/completions/bash/grok.bash"
# <<< grok installer <<<
