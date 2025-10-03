unlock_bw_if_locked() {
  if [[ -z $BW_SESSION ]] ; then
    >&2 echo 'bw locked - unlocking into a new session'
    # Retrieve Bitwarden password from keyring
    export BW_PASS="$(secret-tool lookup service bw-cli username "$USER")"
    if [[ -z "$BW_PASS" ]]; then
      >&2 echo "Bitwarden CLI password not found in keyring for $USER."
      >&2 echo "Run: secret-tool store --label='Bitwarden CLI Password' service bw-cli username \"$USER\""
      return 1
    fi
    export BW_SESSION="$(bw unlock --raw --passwordenv BW_PASS)"
    unset BW_PASS
  fi
}


bw-env() {
  unlock_bw_if_locked
  local search="$@"
  keys_string=$(bw get username $search)
  if [[ $? != 0 ]] ; then
    return
  fi
  values_string=$(bw get password $search)
  read -a keys <<< "$keys_string"
  read -a values <<< "$values_string"

  # Use the last value for remaining keys if there are fewer values.
  last_value=""
  for i in "${!keys[@]}"; do
    if [[ -n "${values[$i]}" ]]; then
      last_value="${values[$i]}"
    fi
    export "${keys[$i]}"="$last_value"
    >&2 echo "Loaded ${keys[$i]}"
  done
}
