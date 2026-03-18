if [ -x "$HOME/Applications/proton-login" ]; then
  export PROTON_LOGIN="$HOME/Applications/proton-login"

  proton-pass-login() {
    "$PROTON_LOGIN" "$@"
  }
fi
