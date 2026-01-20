# ~/.bash_aliases
alias ll='ls -alF'
alias la='ls -alF'
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ] || [ "$ID" = "pop" ]; then
        alias update='sudo apt update && sudo apt upgrade'
    elif [ "$ID" = "fedora" ]; then
        alias update='sudo dnf upgrade'
    fi
fi
if command -v kubectl &>/dev/null; then
    alias k="kubectl"
fi


alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias avante='nvim -c "lua vim.defer_fn(function()require(\"avante.api\").zen_mode()end, 100)"'

alias g='lazygit'
