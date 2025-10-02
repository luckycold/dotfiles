# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository Overview

This is a GNU Stow-based dotfiles repository with a profile-based architecture. It manages shell configurations, Neovim setup, and environment settings across different contexts (personal/work).

## Common Commands

### First time setup
```bash
# Clone the repository (if not already done)
git clone https://github.com/luckycold/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Install baseline configuration
stow -t ~ common

# Optionally install a profile overlay
stow -t ~ personal  # or: stow -t ~ work
```

### Profile Management
```bash
# Interactive profile switcher (provided by the repo)
stow-profile

# Manual profile switching
stow -D -t ~ personal    # Unstow personal
stow -D -t ~ work        # Unstow work
stow -t ~ personal       # Stow personal

# Return to common-only configuration
stow -D -t ~ personal
stow -D -t ~ work
stow -t ~ common
```

### Keeping Dotfiles in Sync
```bash
# Check for and apply updates (interactive with GUI/terminal prompts)
update-dotfiles

# Force an immediate update check
check-dotfiles-now

# Note: Background update check runs automatically on shell startup
# It uses notifications if available and doesn't block terminal initialization
```

### Shell Configuration
```bash
# Reload shell configuration after making changes
source ~/.bashrc
```

### Neovim
```bash
# Launch Neovim (first run will auto-install plugins via lazy.nvim)
nvim

# Manage plugins inside Neovim
:Lazy
```

## Architecture

### Profile System
- **common/**: Baseline configuration files that should always be active
  - `.bashrc`: Main shell configuration with cross-distro compatibility
  - `.bashrc.d/`: Modular shell configuration snippets
  - `.config/nvim/`: Neovim configuration (kickstart.nvim based)
  - `.config/envman/`: Environment manager integration

- **personal/**: Optional overlay for personal machine configurations
  - Adds or overrides files from common
  - Example: `.bashrc.d/exercism_completion.bash`

- **work/**: Optional overlay for work machine configurations
  - Adds or overrides files from common
  - Example: `.config/aerospace/aerospace.toml`

**Key principle**: Only one overlay (personal OR work) should be active at a time, plus common. The `stow-profile` helper ensures this automatically.

### Automated Update System
The repository includes a sophisticated update checker (`common/.bashrc.d/dotfiles_update_check`):

- **Background checking**: Runs on shell startup without blocking
- **Network timeouts**: Uses 10-second timeout for git fetch operations
- **Notification support**: Uses desktop notifications on Linux (notify-send) and macOS (AppleScript)
- **Interactive prompts**: If updates are available, prompts user via GUI or terminal
- **Automatic restowing**: After pulling updates, automatically restows common and offers to apply a profile
- **Shell reload**: Sources `~/.bashrc` after applying updates

Manual commands:
- `update-dotfiles`: Explicitly check and apply updates
- `check-dotfiles-now`: Force immediate check without waiting for background process

### Shell Bootstrap Flow
1. `~/.bashrc` is sourced on shell startup
2. Sources distro-specific global bashrc files (`/etc/bashrc`, `/etc/bash.bashrc`)
3. Adds `~/.local/bin` and `~/bin` to PATH
4. Loads `~/.bash_aliases` if present
5. Sources all files in `~/.bashrc.d/` (modular configuration)
6. Loads bash completion
7. Loads envman environment manager (`~/.config/envman/load.sh`)
8. Sets Warp-specific environment variables (`WARP_ENABLE_WAYLAND=1`, `WGPU_BACKEND=gl`)

### Important Notes

**Repository location**: The dotfiles must live at `~/dotfiles` (hardcoded in helper functions)

**Symlink management**: Stow creates symlinks from this repo to `$HOME`. Be aware that:
- Profile switches modify symlinks in your home directory
- Always commit and sync work before major profile changes
- The `update-dotfiles` command pulls from remote and may overwrite local changes

**Neovim setup**: Based on [kickstart.nvim](https://github.com/luckycold/kickstart.nvim)
- Single-file configuration at `common/.config/nvim/init.lua`
- Uses lazy.nvim for plugin management
- See `common/.config/nvim/README.md` for detailed setup instructions and dependencies

**Environment manager**: Integrates envman for managing PATH, environment variables, aliases, and shell functions
- Configuration at `~/.config/envman/`
- Automatically loaded during shell initialization
