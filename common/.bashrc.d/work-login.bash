netbird-login() {
  if [[ -z ${1:-} ]]; then
    echo "ERROR: Missing environment argument!"
    echo "USAGE: netbird-login [d|s|p] [login-support flags...]"
    return 1
  fi

  local login_dir="$HOME/hydra/operations/support-environment"
  if [[ ! -f "$login_dir/login-support.sh" ]]; then
    login_dir="$HOME/hydra/operations/local-env"
  fi

  if [[ ! -f "$login_dir/login-support.sh" ]]; then
    echo "ERROR: login-support.sh not found in $login_dir"
    return 1
  fi

  # Get a Vault token first; the setup-key NetBird path needs one before NetBird starts.
  source "$login_dir/login-support.sh" "$1" --no-netbird --no-nomad --no-ssh --quiet || return

  # Use the legacy setup-key flow so NetBird does not trigger browser SSO.
  source "$login_dir/login-support.sh" "$1" --netbird-setupkey support-agents --no-nomad --no-ssh "${@:2}" || return

  # Print a short confirmation without making grep failures fail the login.
  netbird status | grep FQDN || true
  netbird status | grep IP || true
}
