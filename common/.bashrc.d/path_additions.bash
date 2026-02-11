if [ -d "$HOME/.local/opt/go/bin" ]; then
    PATH="$PATH:$HOME/.local/opt/go/bin"
fi

if [ -d "$HOME/Applications" ]; then
    PATH="$PATH:$HOME/Applications"
fi

# opencode
if [ -d "$HOME/.opencode/bin" ]; then
    PATH="$PATH:$HOME/.opencode/bin"
fi

# bun
if [ -d "$HOME/.bun" ] && [ -f "$HOME/.bun/bin/bun" ]; then
  PATH="$HOME/.bun/bin:$PATH"
fi

if [ -f "$HOME/.local/bin/env" ]; then
    . "$HOME/.local/bin/env"
fi

export PATH
