if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
fi

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

# bun (cache bin)
if [ -d "$HOME/.cache/.bun/bin" ]; then
  PATH="$HOME/.cache/.bun/bin:$PATH"
fi

if [ -f "$HOME/.local/bin/env" ]; then
    . "$HOME/.local/bin/env"
fi

export PATH
