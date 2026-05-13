netbird-login() {
  if [[ -z ${1:-} ]]; then
    echo "ERROR: Missing environment argument!"
    echo "USAGE: netbird-login [d|s|p] [login-support flags...]"
    return 1
  fi

  local login_dir="$HOME/hydra/operations/local-env"
  if [[ ! -f "$login_dir/login-support.sh" ]]; then
    echo "ERROR: login-support.sh not found in $login_dir"
    return 1
  fi

  # login-support handles Vault, SSH signing, Nomad, NetBird, and local env files.
  source "$login_dir/login-support.sh" "$@" || return

  # Print a short confirmation without making grep failures fail the login.
  netbird status | grep FQDN || true
  netbird status | grep IP || true
}
