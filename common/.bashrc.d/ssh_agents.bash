# Bitwarden SSH Agent setup
if command -v bitwarden-desktop &> /dev/null; then
  export SSH_AUTH_SOCK=~/.bitwarden-ssh-agent.sock
  SSH_AGENT_ACTIVE=1
fi
