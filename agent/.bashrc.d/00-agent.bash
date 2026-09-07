# Headless agent profile: keep host tools available without changing common.
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

# A scoped agent should render only the configs needed for its current task.
# Manual init-env-secrets remains available; do not fetch every desktop/work
# credential merely because a new shell starts.
export _SECRET_AUTO_REFRESH_STARTED=1

