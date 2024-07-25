# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
bw-stay-logged-in() {
    export BW_SESSION=$(bw unlock --raw)
}

export XDG_DATA_DIRS=$XDG_DATA_DIRS:/var/lib/flatpak/exports/share:/home/lucky/.local/share/flatpak/exports/share
export SSH_AUTH_SOCK=/home/$USER/.var/app/com.quexten.Goldwarden/data/ssh-auth-sock
alias gw='flatpak run --command=goldwarden com.quexten.Goldwarden'
export PATH=$PATH:$HOME/go/bin
export EDITOR=nvim
