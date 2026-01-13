# Hardcoded template locations (template:output)
_SECRET_TEMPLATES=(
  # For Kagi-Ken MCP (https://github.com/czottmann/kagi-ken-mcp)
  "$HOME/.kagi_session_token.template:$HOME/.kagi_session_token"
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
