if [ -d "$HOME/.local/opt/go/bin" ]; then
    PATH="$PATH:$HOME/.local/opt/go/bin"
fi

if [ -d "$HOME/Applications" ]; then
    PATH="$PATH:$HOME/Applications"
fi

export PATH