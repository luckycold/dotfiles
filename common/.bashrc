# General Terminal Setup

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
    pushd "$dotfiles_dir" > /dev/null || return 1

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

    popd > /dev/null
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

# Check for dotfiles updates
check_dotfiles_update() {
    # Only check if we're in an interactive shell
    case $- in
        *i*) ;;
          *) return;;
    esac

    local dotfiles_dir="$HOME/dotfiles" # Assume fixed location

    # Check if dotfiles directory exists and contains .git
    if [ -d "$dotfiles_dir/.git" ]; then
        # Change to the dotfiles directory (temporarily, _switch_dotfiles_profile does its own pushd/popd)
        pushd "$dotfiles_dir" > /dev/null
        
        # Check for updates using HTTPS (no SSH agent interaction) with timeout
        # Use timeout command to avoid hangs when offline
        echo "Checking for dotfiles updates..." # Add feedback
        if ! timeout 5s GIT_TERMINAL_PROMPT=0 git -c url.https://github.com/.insteadOf=git@github.com: fetch --no-tags --quiet 2>/dev/null; then
             echo "Update check timed out (likely offline). Skipping." >&2
             popd > /dev/null # Ensure we popd even on timeout
             return 0         # Exit the function gracefully
        fi
        echo "Update check complete."
        
        # Compare local and remote
        local local_head=$(git rev-parse HEAD)
        local remote_head=$(git rev-parse @{u} 2>/dev/null) # Check remote exists
        
        # Only proceed if remote tracking branch exists
        if [ -n "$remote_head" ] && [ "$local_head" != "$remote_head" ]; then
            # Check if local is ahead
            if git merge-base --is-ancestor "$remote_head" "$local_head" 2>/dev/null; then
                # Local is ahead, just notify
                echo -e "\n\033[1;33mYour dotfiles are out of sync with the repo (you're ahead)\033[0m"
            else
                # Local is behind (or diverged), notify and prompt
                echo -e "\n\033[1;33mYour dotfiles are out of date!\033[0m"
                echo "Would you like to update and restow your dotfiles? (y/n)"
                read -r response
                if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                    echo "Updating dotfiles..."
                    git pull
                    echo "Restowing common files..."
                    stow -t ~ common
                    
                    echo "Restow profile? (personal/work) [Enter to skip]"
                    read -r profile
                    # Call the refactored function
                    _switch_dotfiles_profile "$profile"
                fi
            fi
        fi
        
        # Return to original directory
        popd > /dev/null
    fi
}

# Run the update check
check_dotfiles_update