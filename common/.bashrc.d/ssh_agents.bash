# Proton Pass SSH Agent setup
PROTON_PASS_AGENT_SOCK="$HOME/.ssh/proton-pass-agent.sock"
if [ -S "$PROTON_PASS_AGENT_SOCK" ]; then
  export SSH_AUTH_SOCK="$PROTON_PASS_AGENT_SOCK"
  SSH_AGENT_ACTIVE=1
fi
