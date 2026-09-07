# Headless agent profile: keep host tools available without changing common.
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

# A scoped agent should render only the configs needed for its current task.
# Manual init-env-secrets remains available; do not fetch every desktop/work
# credential merely because a new shell starts.
export _SECRET_AUTO_REFRESH_STARTED=1


# Reuse the scoped session on hosts provisioned with the agent CLI wrapper.
# Do not create a second session or inherit a desktop/root session directory.
if [ -x "$HOME/.local/bin/proton-pass-agent" ] && [ -d "$HOME/.local/share/proton-pass" ]; then
  export PROTON_PASS_SESSION_DIR="$HOME/.local/share/proton-pass"
  export PROTON_PASS_KEY_PROVIDER=fs
fi
