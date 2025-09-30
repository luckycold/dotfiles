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
if flatpak list | grep -q "com.quexten.Goldwarden"; then
    alias goldwarden="flatpak run --command=goldwarden com.quexten.Goldwarden"
fi
if kubectl version --client=true | grep -qi "Client"; then
    alias k="kubectl"
fi
