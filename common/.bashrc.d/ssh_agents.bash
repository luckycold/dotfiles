# Proton Pass SSH Agent setup
PROTON_PASS_AGENT_SOCK="$HOME/.ssh/proton-pass-agent.sock"
# Keep using Proton Pass even when a shell opens before the service is ready.
export SSH_AUTH_SOCK="$PROTON_PASS_AGENT_SOCK"
SSH_AGENT_ACTIVE=0
# A stopped agent can leave a stale socket behind. Require loaded identities.
if [ -S "$SSH_AUTH_SOCK" ] && ssh-add -l >/dev/null 2>&1; then
  SSH_AGENT_ACTIVE=1
fi
