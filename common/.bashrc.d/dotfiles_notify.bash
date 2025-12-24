# Dotfiles Update Notification System
# Provides action-based notifications for dotfile updates with fallback for headless environments

send_dotfiles_notification() {
  local summary="Dotfiles Update Available"
  local body="Run 'update-dotfiles' to update your configuration"

  # Check if notification daemon is running
  if pgrep -x "mako" > /dev/null 2>&1; then
    # Send notification with action and 30-second timeout
    # Blocks until action clicked or timeout, spawns terminal in background
    local action
    action=$(notify-send -u normal -i dialog-information \
      -A "default=Update Now" \
      -A "dismiss=Dismiss" \
      -t 30000 \
      -w \
      "$summary" "$body")

    # Debug logging
    # echo "Action received: $action" >> /tmp/dotfiles-notify.log

    case "$action" in
      default)
        # Spawn update terminal in background
        if command -v omarchy-launch-floating-terminal-with-presentation 2>/dev/null; then
          omarchy-launch-floating-terminal-with-presentation "source $HOME/dotfiles/common/.bashrc.d/dotfiles_management.bash && update-dotfiles" &
        else
          xdg-terminal-exec --title="Dotfiles Update" -e bash -c "source $HOME/dotfiles/common/.bashrc.d/dotfiles_management.bash && update-dotfiles" &
        fi

        # Wait for terminal to spawn
        sleep 1
        ;;
      dismiss|"")
        # User dismissed or timed out, nothing to do
        ;;
    esac
  else
    # Backup notifier for headless environments
    echo -e "\n\033[1;33m━━━ Dotfiles Update Available ━━━\033[0m"
    echo -e "\033[0;33m$body\033[0m"
    echo -e "\033[0;33mRun: update-dotfiles\033[0m"
  fi
}
