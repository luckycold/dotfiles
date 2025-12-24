# Ensure Omarchy mako actionable overlay is applied
# Portable helper: runs on shell startup via common/.bashrc

_mako_apply_actionable_overlay() {
  local theme_mako
  theme_mako="$HOME/.config/omarchy/current/theme/mako.ini"

  # Only proceed if the current theme mako.ini exists
  if [ ! -f "$theme_mako" ]; then
    return 0
  fi

  # If we've already applied the overlay (recognizable marker), skip
  if grep -q "# Omarchy actionable overlay" "$theme_mako" 2>/dev/null; then
    return 0
  fi

  # Append actionable styling + Walker middle-click menu
  {
    echo ""
    echo "# Omarchy actionable overlay (portable via dotfiles)"
    echo "# Style notifications with actions and enable Walker action menu on middle-click"
    echo "[actionable=true]"
    echo "border-color=#FFA500"
    echo "border-size=3"
    echo "on-button-middle=exec makoctl menu -n \"$id\" -- walker --dmenu -p 'Select action: '"
  } >>"$theme_mako"
}

_mako_apply_actionable_overlay
unset -f _mako_apply_actionable_overlay
