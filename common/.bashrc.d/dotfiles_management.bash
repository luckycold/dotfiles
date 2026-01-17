#!/bin/bash
# Dotfiles Management and Update Checker (merged)

# Desktop notification helper (freedesktop.org spec)
_can_send_desktop_notification() {
    command -v notify-send &>/dev/null || return 1
    [ -n "${DBUS_SESSION_BUS_ADDRESS-}" ] || return 1

    # Probe for a running notification service if possible
    if command -v gdbus &>/dev/null; then
        gdbus call --session \
            --dest org.freedesktop.Notifications \
            --object-path /org/freedesktop/Notifications \
            --method org.freedesktop.Notifications.GetServerInformation \
            >/dev/null 2>&1 || return 1
    fi

    return 0
}

_notify_desktop() {
    _can_send_desktop_notification || return 1
    notify-send "$@" 2>/dev/null
}

_dotfiles_notifications_available() {
    # Prefer checking D-Bus ownership (most universal).
    if command -v gdbus &>/dev/null; then
        local has_owner
        has_owner=$(gdbus call --session \
            --dest org.freedesktop.DBus \
            --object-path /org/freedesktop/DBus \
            --method org.freedesktop.DBus.NameHasOwner \
            org.freedesktop.Notifications 2>/dev/null) || return 1

        case "$has_owner" in
            *true*) return 0 ;;
            *) return 1 ;;
        esac
    fi

    # Fallback for systems without gdbus.
    if command -v busctl &>/dev/null; then
        busctl --user --quiet status org.freedesktop.Notifications >/dev/null 2>&1
        return $?
    fi

    return 1
}

# Send notification about available updates
# Wrapper to ensure we use the new action-based notification system
send_update_notification() {
    # If the new function exists, use it
    if command -v send_dotfiles_notification &>/dev/null; then
        send_dotfiles_notification
        return $?
    fi

    # Fallback to sourcing the file if function not found (e.g. background subshell)
    if [ -f "$HOME/dotfiles/common/.bashrc.d/dotfiles_notify.bash" ]; then
        source "$HOME/dotfiles/common/.bashrc.d/dotfiles_notify.bash"
        if command -v send_dotfiles_notification &>/dev/null; then
            send_dotfiles_notification
            return $?
        fi
    fi

    # Legacy fallback if something is really broken
    if command -v osascript &>/dev/null; then
        osascript -e 'display notification "Run update-dotfiles to update" with title "Dotfiles Update Available"' 2>/dev/null || return 1
    elif _notify_desktop "Dotfiles Update Available" "Run 'update-dotfiles' to update"; then
        return 0
    else
        return 1
    fi
}

# Background check for updates (runs once per shell session)
background_dotfiles_check() {
    # Only check once per shell session
    [ -n "$_DOTFILES_CHECKED" ] && return 0
    export _DOTFILES_CHECKED=1

    local dotfiles_dir="$HOME/dotfiles"
    [ ! -d "$dotfiles_dir/.git" ] && return 0

    # Run check in background (suppress job notifications in zsh)
    if [ -n "$ZSH_VERSION" ]; then
        # In zsh, use proper job control to suppress notifications
        {
            (
                cd "$dotfiles_dir" 2>/dev/null || exit 0

                # Fetch with timeout
                if command -v timeout &>/dev/null; then
                    timeout 10s git fetch --quiet 2>/dev/null
                elif command -v gtimeout &>/dev/null; then
                    gtimeout 10s git fetch --quiet 2>/dev/null
                else
                    git fetch --quiet 2>/dev/null
                fi

                # Check if behind remote
                if [ $? -eq 0 ]; then
                    local local_head=$(git rev-parse HEAD 2>/dev/null)
                    local remote_head=$(git rev-parse @{u} 2>/dev/null)

                    if [ -n "$remote_head" ] && [ "$local_head" != "$remote_head" ]; then
                        if ! git merge-base --is-ancestor "$remote_head" "$local_head" 2>/dev/null; then
                            # Send action-based notification with terminal update support
                            send_update_notification
                        fi
                    fi
                fi
            ) &!
        } 2>/dev/null
    else
        # In bash, use standard approach
        (
            cd "$dotfiles_dir" 2>/dev/null || exit 0

            # Fetch with timeout
            if command -v timeout &>/dev/null; then
                timeout 10s git fetch --quiet 2>/dev/null
            elif command -v gtimeout &>/dev/null; then
                gtimeout 10s git fetch --quiet 2>/dev/null
            else
                git fetch --quiet 2>/dev/null
            fi

            # Check if behind remote
            if [ $? -eq 0 ]; then
                local local_head=$(git rev-parse HEAD 2>/dev/null)
                local remote_head=$(git rev-parse @{u} 2>/dev/null)

                if [ -n "$remote_head" ] && [ "$local_head" != "$remote_head" ]; then
                    if ! git merge-base --is-ancestor "$remote_head" "$local_head" 2>/dev/null; then
                        # Send action-based notification with terminal update support
                        send_update_notification
                    fi
                fi
            fi
        ) &
        disown
    fi
}

# Manual update command (includes profile management after update)
update-dotfiles() {
    local dotfiles_dir="$HOME/dotfiles"
    local original_dir="$(pwd)"

    [ ! -d "$dotfiles_dir/.git" ] && echo "Error: Dotfiles not found at $dotfiles_dir" && return 1

    cd "$dotfiles_dir" || return 1

    # Check for updates
    echo "Checking for updates..."
    git fetch --quiet || { echo "Failed to check for updates"; cd "$original_dir"; return 1; }

    local local_head=$(git rev-parse HEAD)
    local remote_head=$(git rev-parse @{u} 2>/dev/null)

    if [ "$local_head" = "$remote_head" ]; then
        echo "Already up to date!"
        cd "$original_dir"
        return 0
    fi

    # Pull updates
    echo "Pulling updates..."
    git pull || { echo "Failed to pull updates"; cd "$original_dir"; return 1; }

    # Ask for profile
    local profiles=()
    local i=1

    echo "Which profile would you like?"
    echo "  1) none (common only)"
    while IFS= read -r profile; do
      ((i++))
      profiles+=("$profile")
      echo "  $i) $profile"
    done < <(_list_dotfiles_profiles)
    echo ""
    echo -n "Enter choice [1-$i]: "
    read -r choice

    local target_profile="none"
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 2 && choice <= i )); then
      target_profile="${profiles[$((choice - 2))]}"
    fi

    _switch_dotfiles_profile "$target_profile"

    # Ask to reload bashrc
    echo -n "Reload shell configuration? (y/n): "
    read -r reload

    if [[ "$reload" =~ ^[yY]$ ]]; then
        source ~/.bashrc
        echo "Configuration reloaded"
    fi

    # Send completion notification since we actually updated
    # Prefer notifications when available, fall back to terminal output.
    if command -v notify-send &>/dev/null; then
        if ! notify-send -u normal -i dialog-information "Update Complete" "Restart your terminals to apply changes" 2>/dev/null; then
            echo "Update complete. Restart your terminals to apply changes."
        fi
    else
        echo "Update complete. Restart your terminals to apply changes."
    fi

    cd "$original_dir"
}

# --- Dotfiles Profile Management Functions ---

# Internal function to switch stow profiles
_switch_dotfiles_profile() {
  local target_profile="$1"
  local dotfiles_dir="$HOME/dotfiles"

  if [ ! -d "$dotfiles_dir" ]; then
    echo "Error: Dotfiles directory '$dotfiles_dir' not found." >&2
    return 1
  fi

  echo "Switching profile in $dotfiles_dir..."
  pushd "$dotfiles_dir" >/dev/null || return 1

  # Unstow all non-common profiles (any directory that isn't common or hidden)
  echo "(Unstowing existing profiles...)"
  for dir in */; do
    dir="${dir%/}"
    [[ "$dir" == "common" ]] && continue
    stow -D -t ~ "$dir" 2>/dev/null
  done

  # Always restow common
  if [ -d "common" ]; then
    echo "Restowing 'common' profile..."
    stow -R -t ~ common
  fi

  # Stow the target profile if specified and not "none"
  if [[ -n "$target_profile" && "$target_profile" != "none" ]]; then
    if [[ "$target_profile" == "common" ]]; then
      echo "Note: 'common' is always included, no additional profile selected."
    elif [ -d "$target_profile" ]; then
      echo "Restowing '$target_profile' profile..."
      if stow -R -t ~ "$target_profile"; then
        echo "Profile '$target_profile' stowed successfully."
      else
        echo "Error stowing profile '$target_profile'." >&2
        popd >/dev/null
        return 1
      fi
    else
      echo "Error: Profile directory '$target_profile' not found." >&2
      popd >/dev/null
      return 1
    fi
  else
    echo "Only 'common' profile is now active."
  fi

  popd >/dev/null

  # Reload Hyprland configuration if applicable
  if command -v hyprctl &>/dev/null && pgrep -x Hyprland &>/dev/null; then
    echo "Reloading Hyprland configuration..."
    hyprctl reload >/dev/null 2>&1
  fi

  echo "Profile switch complete."
}

# List available profiles
_list_dotfiles_profiles() {
  local dotfiles_dir="$HOME/dotfiles"
  local profiles=()

  for dir in "$dotfiles_dir"/*/; do
    dir="${dir%/}"
    dir="${dir##*/}"
    [[ "$dir" == "common" ]] && continue
    profiles+=("$dir")
  done

  printf '%s\n' "${profiles[@]}"
}

# Function to manually switch profiles
# Usage: stow-profile [profile_name]
stow-profile() {
  local target_profile="$1"

  # If no argument provided, show numbered menu
  if [[ -z "$target_profile" ]]; then
    local profiles=()
    local i=1

    echo "Available profiles:"
    echo "  1) none (common only)"
    while IFS= read -r profile; do
      ((i++))
      profiles+=("$profile")
      echo "  $i) $profile"
    done < <(_list_dotfiles_profiles)
    echo ""
    echo -n "Enter choice [1-$i]: "
    read -r choice

    if [[ -z "$choice" ]]; then
      echo "No selection made. Aborting."
      return 1
    fi

    if [[ "$choice" == "1" ]]; then
      target_profile="none"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 2 && choice <= i )); then
      target_profile="${profiles[$((choice - 2))]}"
    else
      echo "Invalid choice. Aborting."
      return 1
    fi
  fi

  _switch_dotfiles_profile "$target_profile"
}

# Run check on shell startup
background_dotfiles_check
