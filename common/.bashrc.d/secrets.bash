_secret_usage() {
  printf '%s\n' "Usage: init-env-secrets [options]"
  printf '%s\n' ""
  printf '%s\n' "Options:"
  printf '%s\n' "  -f, --force            Regenerate even when output looks up to date"
  printf '%s\n' "  -r, --retry [selector] Retry selector and re-inject even if up to date"
  printf '%s\n' "  -a, --all              Process all matched secrets (skip interactive picker)"
  printf '%s\n' "  -l, --list             List active secrets and status, then exit"
  printf '%s\n' "  -h, --help             Show this help"
}

_secret_discover_active_mappings() {
  local dotfiles_dir="${DOTFILES_DIR:-$HOME/dotfiles}"
  local rel rel_in_package repo_template home_template output_rel output template_source
  local key score record
  local -a key_order=()
  declare -A chosen_score=()
  declare -A chosen_record=()

  if ! command -v git >/dev/null 2>&1; then
    echo "git is required to discover secret templates." >&2
    return 1
  fi

  if [ ! -d "$dotfiles_dir/.git" ]; then
    echo "Dotfiles git repo not found: $dotfiles_dir" >&2
    return 1
  fi

  while IFS= read -r -d '' rel; do
    [[ "$rel" =~ \.template\.[^.]+$ ]] || continue
    [[ "$rel" == */* ]] || continue

    rel_in_package="${rel#*/}"
    repo_template="$dotfiles_dir/$rel"
    home_template="$HOME/$rel_in_package"

    # Only include templates that exist in HOME (stowed or local override).
    [ -e "$home_template" ] || continue

    output_rel="${rel_in_package/.template./.}"
    output="$HOME/$output_rel"

    template_source="$home_template"
    score=0
    if [ "$home_template" -ef "$repo_template" ]; then
      template_source="$repo_template"
      score=2
    elif [ ! -L "$home_template" ]; then
      score=1
    fi

    key="$rel_in_package"
    record="$rel"$'\t'"$template_source"$'\t'"$output"

    if [ -z "${chosen_record[$key]+x}" ]; then
      key_order+=("$key")
      chosen_score[$key]="$score"
      chosen_record[$key]="$record"
    elif (( score > chosen_score[$key] )); then
      chosen_score[$key]="$score"
      chosen_record[$key]="$record"
    fi
  done < <(git -C "$dotfiles_dir" ls-files -z --cached --others --exclude-standard)

  for key in "${key_order[@]}"; do
    printf '%s\n' "${chosen_record[$key]}"
  done
}

_secret_matches_selector() {
  local selector="$1"
  local id="$2"
  local template="$3"
  local output="$4"

  [[ "$id" == "$selector" ]] && return 0
  [[ "$template" == "$selector" ]] && return 0
  [[ "$output" == "$selector" ]] && return 0

  [[ "$id" == *"$selector"* ]] && return 0
  [[ "$template" == *"$selector"* ]] && return 0
  [[ "$output" == *"$selector"* ]] && return 0

  return 1
}

_secret_record_selected() {
  local needle="$1"
  local selected

  for selected in "${_SECRET_SELECTED_RECORDS[@]}"; do
    [[ "$selected" == "$needle" ]] && return 0
  done

  return 1
}

_secret_select_records_fallback() {
  local selection token idx record

  echo "Select secrets by number (comma-separated), 'a' for all, or Enter to cancel:"
  printf '> '
  read -r selection

  if [ -z "$selection" ]; then
    return 1
  fi

  if [[ "$selection" =~ ^[aA]$ ]]; then
    _SECRET_SELECTED_RECORDS=("${_SECRET_DISCOVERED_RECORDS[@]}")
    return 0
  fi

  selection="${selection//,/ }"
  for token in $selection; do
    if ! [[ "$token" =~ ^[0-9]+$ ]]; then
      echo "Invalid selection: $token" >&2
      return 1
    fi

    idx=$((token - 1))
    if (( idx < 0 || idx >= ${#_SECRET_DISCOVERED_RECORDS[@]} )); then
      echo "Selection out of range: $token" >&2
      return 1
    fi

    record="${_SECRET_DISCOVERED_RECORDS[$idx]}"
    if ! _secret_record_selected "$record"; then
      _SECRET_SELECTED_RECORDS+=("$record")
    fi
  done

  return 0
}

_secret_select_records() {
  local -a ids selected_ids
  local record id template output selected_id

  _SECRET_SELECTED_RECORDS=()

  for record in "${_SECRET_DISCOVERED_RECORDS[@]}"; do
    IFS=$'\t' read -r id template output <<< "$record"
    ids+=("$id")
  done

  if command -v fzf >/dev/null 2>&1; then
    while IFS= read -r selected_id; do
      [ -n "$selected_id" ] && selected_ids+=("$selected_id")
    done < <(printf '%s\n' "${ids[@]}" | fzf --multi --prompt="Select secret(s) > " --height=40% --reverse)

    if (( ${#selected_ids[@]} == 0 )); then
      return 1
    fi

    for selected_id in "${selected_ids[@]}"; do
      for record in "${_SECRET_DISCOVERED_RECORDS[@]}"; do
        IFS=$'\t' read -r id template output <<< "$record"
        [[ "$id" == "$selected_id" ]] || continue
        _SECRET_SELECTED_RECORDS+=("$record")
        break
      done
    done

    return 0
  fi

  local i=0
  echo "Available secrets:"
  for record in "${_SECRET_DISCOVERED_RECORDS[@]}"; do
    IFS=$'\t' read -r id template output <<< "$record"
    ((i++))
    printf '  %d) %s -> %s\n' "$i" "$id" "$output"
  done

  _secret_select_records_fallback
}

init-env-secrets() {
  local force=0
  local list_only=0
  local all=0
  local retry_picker=0
  local retry_mode=0
  local -a selectors=()
  local -a matched_records=()
  local record id template output selector
  local updated=0 skipped=0 failed=0

  while (( $# > 0 )); do
    case "$1" in
      -f|--force)
        force=1
        ;;
      -r|--retry)
        retry_mode=1
        if [ -n "${2-}" ] && [[ "${2}" != -* ]]; then
          selectors+=("$2")
          shift
        else
          retry_picker=1
        fi
        ;;
      --retry=*)
        retry_mode=1
        selectors+=("${1#--retry=}")
        ;;
      -a|--all)
        all=1
        ;;
      -l|--list)
        list_only=1
        ;;
      -h|--help)
        _secret_usage
        return 0
        ;;
      --)
        shift
        selectors+=("$@")
        break
        ;;
      *)
        selectors+=("$1")
        ;;
    esac
    shift
  done

  _SECRET_DISCOVERED_RECORDS=()
  while IFS= read -r record; do
    [ -n "$record" ] && _SECRET_DISCOVERED_RECORDS+=("$record")
  done < <(_secret_discover_active_mappings)

  if (( ${#_SECRET_DISCOVERED_RECORDS[@]} == 0 )); then
    echo "No active secret templates found in $HOME."
    echo "Expected files like: ~/.template.* or ~/.config/**/.template.*"
    return 0
  fi

  if (( ${#selectors[@]} > 0 )); then
    for record in "${_SECRET_DISCOVERED_RECORDS[@]}"; do
      IFS=$'\t' read -r id template output <<< "$record"
      for selector in "${selectors[@]}"; do
        if _secret_matches_selector "$selector" "$id" "$template" "$output"; then
          matched_records+=("$record")
          break
        fi
      done
    done
  elif (( all == 1 )); then
    matched_records=("${_SECRET_DISCOVERED_RECORDS[@]}")
  elif (( retry_picker == 1 )); then
    if [ ! -t 0 ] || [ ! -t 1 ]; then
      echo "--retry without selector requires an interactive terminal." >&2
      return 1
    fi
    if ! _secret_select_records; then
      echo "No secrets selected."
      return 1
    fi
    matched_records=("${_SECRET_SELECTED_RECORDS[@]}")
  elif (( list_only == 1 )) || [ ! -t 0 ] || [ ! -t 1 ]; then
    matched_records=("${_SECRET_DISCOVERED_RECORDS[@]}")
  else
    if ! _secret_select_records; then
      echo "No secrets selected."
      return 1
    fi
    matched_records=("${_SECRET_SELECTED_RECORDS[@]}")
  fi

  if (( ${#matched_records[@]} == 0 )); then
    echo "No secrets matched the provided selector(s)." >&2
    return 1
  fi

  if (( list_only == 1 )); then
    echo "Active secrets:"
    for record in "${matched_records[@]}"; do
      IFS=$'\t' read -r id template output <<< "$record"
      if [ -f "$output" ] && ! [ "$template" -nt "$output" ]; then
        printf '  - %s -> %s [fresh]\n' "$id" "$output"
      else
        printf '  - %s -> %s [stale]\n' "$id" "$output"
      fi
    done
    return 0
  fi

  if ! command -v pass-cli >/dev/null 2>&1; then
    echo "pass-cli is required to inject secrets." >&2
    return 1
  fi

  for record in "${matched_records[@]}"; do
    IFS=$'\t' read -r id template output <<< "$record"

    if [ ! -f "$template" ]; then
      echo "Template not found: $template" >&2
      ((failed++))
      continue
    fi

    if (( force == 0 )) && (( retry_mode == 0 )) && [ -f "$output" ] && ! [ "$template" -nt "$output" ]; then
      echo "Skipped (up to date): $id"
      ((skipped++))
      continue
    fi

    mkdir -p "$(dirname "$output")"

    if pass-cli inject -f -i "$template" -o "$output"; then
      chmod 600 "$output" 2>/dev/null || true
      echo "Updated: $id -> $output"
      ((updated++))
    else
      echo "Failed: $id" >&2
      ((failed++))
    fi
  done

  echo "Secrets refresh complete: updated=$updated skipped=$skipped failed=$failed selected=${#matched_records[@]}"
  (( failed == 0 ))
}
