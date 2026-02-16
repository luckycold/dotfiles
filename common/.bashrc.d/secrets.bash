# Hardcoded template locations (template:output)
_SECRET_TEMPLATES=(
  # For Kagi-Ken MCP (https://github.com/czottmann/kagi-ken-mcp)
  "$HOME/.template.kagi_session_token:$HOME/.kagi_session_token"
  # For OpenCode Smart Voice Notify (https://github.com/MasuRii/opencode-smart-voice-notify)
  "$HOME/.config/opencode/smart-voice-notify.template.jsonc:$HOME/.config/opencode/smart-voice-notify.jsonc"
)

init-env-secrets() {
  local entry template output

  for entry in "${_SECRET_TEMPLATES[@]}"; do
    template="${entry%%:*}"
    output="${entry##*:}"

    if [[ ! -f "$template" ]]; then
      echo "Template not found: $template"
      continue
    fi

    pass-cli inject -i "$template" -o "$output"
    chmod 600 "$output"
    echo "Created: $output"
  done
}
