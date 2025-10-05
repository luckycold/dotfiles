# Avante - Dotfiles Overview

This document outlines the main dotfiles in this repository with a focus on the Neovim configuration and bashrc profile system.

## Repository Structure

This is a GNU Stow-based dotfiles repository with a profile-based architecture:

```
dotfiles/
├── common/          # Baseline configuration (always active)
├── personal/        # Personal machine overlay (optional)
├── work/           # Work machine overlay (optional)
└── README.md
```

**Key Principle**: Only one overlay (personal OR work) should be active at a time, plus common.

## Neovim Configuration

### Main Configuration
- **Location**: `common/.config/nvim/init.lua`
- **Base**: Built on [kickstart.nvim](https://github.com/luckycold/kickstart.nvim)
- **Plugin Manager**: Uses lazy.nvim for plugin management
- **Leader Key**: Space (`' '`)

### Core Structure
```
common/.config/nvim/
├── init.lua                    # Main entry point
├── lua/
│   ├── options.lua            # Editor options and settings
│   ├── keymaps.lua            # Basic key mappings
│   ├── lazy-bootstrap.lua     # Lazy.nvim bootstrap
│   ├── lazy-plugins.lua       # Plugin registry
│   └── lucky/
│       ├── plugins/           # Modular plugin configs
│       └── health.lua         # Health check
└── README.md                  # Detailed setup instructions
```

### Key Plugin Modules

#### Essential Plugins
- **LSP Configuration** (`lsp-config.lua`): Language Server Protocol setup with Mason
- **Telescope** (`telescope.lua`): Fuzzy finder for files, buffers, LSP, etc.
- **Treesitter** (`treesitter.lua`): Enhanced syntax highlighting and code understanding
- **Which-Key** (`which-key.lua`): Interactive keybinding helper
- **Git Signs** (`gitsigns.lua`): Git integration in the editor

#### Development Tools
- **Completion** (`cmp.lua`): Code completion with nvim-cmp
- **Autoformat** (`conform.lua`): Automatic code formatting
- **Debugging** (`debug.lua`): Debug Adapter Protocol support
- **Refactoring** (`refactoring.lua`): Code refactoring tools
- **Linting** (`lint.lua`): Linting and diagnostics

#### UI & Themes
- **Tokyo Night** (`tokyonight.lua`): Color theme
- **Todo Comments** (`todo-comments.lua`): Highlight TODO/FIXME/NOTE comments
- **Mini** (`mini.lua`): Collection of small utility plugins
- **Indent Line** (`indent_line.lua`): Visual indentation guides

#### Advanced Features
- **Avante** (`avante.lua`): AI-powered code assistant
- **ChatGPT** (`chatgpt.lua`): ChatGPT integration
- **ToggleTerm** (`toggleterm.lua`): Floating terminal
- **Overseer** (`overseer.lua`): Task runner and build system
- **Neo-Tree** (`neo-tree.lua`): File explorer sidebar
- **CMake Tools** (`cmake-tools.lua`): CMake project support

### Plugin Management
```bash
# Inside Neovim:
:Lazy           # Open plugin manager
:Lazy update    # Update all plugins
:Lazy clean     # Remove unused plugins
```

## Bash Configuration

### Main Bashrc
- **Location**: `common/.bashrc`
- **Approach**: Cross-distro compatible (Fedora/Debian/Ubuntu/Pop_OS)
- **Size**: 185 lines with comprehensive setup

### Key Features

#### Cross-Distro Compatibility
```bash
# Sources appropriate global bashrc based on distribution
[ -f /etc/bashrc ] && . /etc/bashrc           # Fedora/RHEL
[ -f /etc/bash.bashrc ] && . /etc/bash.bashrc # Debian/Ubuntu/Pop_OS
```

#### PATH Management
```bash
# Ensures user binaries are in PATH
PATH="$HOME/.local/bin:$HOME/bin:$PATH"
```

#### Color Support & Aliases
- Automatic color detection for terminal capabilities
- Colorized `ls`, `grep`, `fgrep`, `egrep`
- Support for custom `~/.dircolors`

#### Modular Configuration
```bash
# Sources all files in ~/.bashrc.d/ directory
for rc in ~/.bashrc.d/*; do
  if [ -f "$rc" ]; then
    . "$rc"
  fi
done
```

### Profile System

#### Profile Architecture
- **Common** (`common/`): Base configuration always active
- **Personal** (`personal/`): Personal machine additions/overrides
- **Work** (`work/`): Work machine additions/overrides

#### Profile Management Functions

**Interactive Profile Switcher**:
```bash
stow-profile    # Interactive menu to switch profiles
```

**Manual Profile Switching**:
```bash
# Switch to personal profile
stow -D -t ~ work && stow -t ~ personal

# Switch to work profile
stow -D -t ~ personal && stow -t ~ work

# Common only
stow -D -t ~ personal && stow -D -t ~ work && stow -t ~ common
```

### Modular Components (`~/.bashrc.d/`)

#### Core Modules
- **`bw-env`**: Bitwarden SSH Agent setup
- **`path_additions`**: Additional PATH modifications
- **`neovim`**: Neovim-specific environment setup
- **`dotfiles_update_check`**: Automated update system

#### Update System (`dotfiles_update_check`)
- **Background Checking**: Runs on shell startup without blocking
- **Network Timeouts**: 10-second timeout for git operations
- **Notification Support**: Desktop notifications on Linux/macOS
- **Manual Commands**:
  ```bash
  update-dotfiles        # Check and apply updates
  ```

#### Personal Profile Additions
- **`exercism_completion.bash`**: Bash completion for Exercism CLI

#### Work Profile Additions
- **`aerospace/aerospace.toml`**: Window manager configuration for macOS

### Environment Integration

#### Envman Integration
```bash
# Automatically loads environment manager
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
```

Location: `common/.config/envman/`
- `load.sh`: Main loader script
- `PATH.env`: PATH variable management
- `ENV.env`: Environment variables
- `alias.env`: Shell aliases
- `function.sh`: Custom shell functions

#### Warp Terminal Support
```bash
export WARP_ENABLE_WAYLAND=1
export WGPU_BACKEND=gl
```

## Usage Examples

### First Time Setup
```bash
cd ~/dotfiles
stow -t ~ common
stow -t ~ personal    # or: stow -t ~ work
```

### Profile Management
```bash
stow-profile           # Interactive profile switching
```

### Keeping Updated
```bash
update-dotfiles        # Check and apply updates (includes profile management)
```

### Neovim Setup
```bash
nvim                   # First run auto-installs plugins
:Lazy                  # Manage plugins inside Neovim
```

## Key Features Summary

### Neovim
- Modular plugin architecture with lazy.nvim
- LSP support with auto-completion
- AI integration (Avante, ChatGPT)
- Extensive theme and UI customization
- Development tools for multiple languages

### Bash Environment
- Cross-distro compatibility
- Profile-based configuration management
- Automated update system with notifications
- Modular .bashrc.d structure
- Environment manager integration
- Git-aware prompt and SSH agent setup

This architecture provides a flexible, maintainable setup that adapts to different contexts (personal/work) while maintaining consistency across different Linux distributions.
