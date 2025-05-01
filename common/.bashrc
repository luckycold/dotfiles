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

# Check for dotfiles updates
check_dotfiles_update() {
    # Only check if we're in an interactive shell
    case $- in
        *i*) ;;
          *) return;;
    esac

    # Get the directory where this .bashrc is located
    local dotfiles_dir
    if [ -L "$HOME/.bashrc" ]; then
        dotfiles_dir="$(dirname "$(readlink -f "$HOME/.bashrc")")"
        dotfiles_dir="$(dirname "$dotfiles_dir")"  # Go up one level to get to dotfiles root
    else
        return  # Not a symlink, probably not managed by stow
    fi

    # Check if we're in a git repository
    if [ -d "$dotfiles_dir/.git" ]; then
        # Change to the dotfiles directory
        pushd "$dotfiles_dir" > /dev/null
        
        # Check for updates using HTTPS (no SSH agent interaction)
        GIT_TERMINAL_PROMPT=0 git -c url.https://github.com/.insteadOf=git@github.com: fetch --no-tags --quiet 2>/dev/null
        
        # Compare local and remote
        local local_head=$(git rev-parse HEAD)
        local remote_head=$(git rev-parse @{u})
        
        if [ "$local_head" != "$remote_head" ]; then
            # Check if we're ahead or behind
            if git merge-base --is-ancestor "$remote_head" "$local_head" 2>/dev/null; then
                echo -e "\n\033[1;33mYour dotfiles are out of sync with the repo (you're ahead)\033[0m"
            else
                echo -e "\n\033[1;33mYour dotfiles are out of date!\033[0m"
            fi
            
            echo "Would you like to update and restow your dotfiles? (y/n)"
            read -r response
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                echo "Updating dotfiles..."
                git pull
                echo "Restowing common files..."
                stow -t ~ common
                
                echo "Restow profile? (personal/work) [Enter to skip]"
                read -r profile
                if [[ "$profile" =~ ^(personal|work)$ ]]; then
                    # Unstow current profile if it exists
                    if [ -d "personal" ] && [ -L "$HOME/.bashrc" ] && [ "$(readlink -f "$HOME/.bashrc")" =~ "/personal/" ]; then
                        echo "Unstowing personal profile..."
                        stow -D -t ~ personal
                    elif [ -d "work" ] && [ -L "$HOME/.bashrc" ] && [ "$(readlink -f "$HOME/.bashrc")" =~ "/work/" ]; then
                        echo "Unstowing work profile..."
                        stow -D -t ~ work
                    fi
                    
                    echo "Restowing $profile files..."
                    stow -t ~ "$profile"
                    echo "Dotfiles updated successfully!"
                elif [[ -z "$profile" || "$profile" == "skip" ]]; then
                    echo "Skipping profile restow. Only common files were updated."
                else
                    echo "Invalid profile. Only common files were restowed."
                fi
            fi
        fi
        
        # Return to original directory
        popd > /dev/null
    fi
}

# Run the update check
check_dotfiles_update