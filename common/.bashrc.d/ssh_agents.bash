# Proton Pass SSH Agent setup
PROTON_PASS_AGENT_SOCK="$HOME/.ssh/proton-pass-agent.sock"
if [ -S "$PROTON_PASS_AGENT_SOCK" ]; then
  export SSH_AUTH_SOCK="$PROTON_PASS_AGENT_SOCK"
  SSH_AGENT_ACTIVE=1
fi

# Bitwarden SSH Agent setup
if command -v bitwarden-desktop &> /dev/null && [ -z "$SSH_AGENT_ACTIVE" ]; then
  export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
  SSH_AGENT_ACTIVE=1
fi

ssh() {
    command ssh "$@"
    local ssh_exit=$?

    if [ $ssh_exit -ne 0 ]; then
        # Check if agent is reachable (0 = keys found, 1 = no keys, 2 = connection refused)
        ssh-add -l >/dev/null 2>&1
        local agent_status=$?

        # If agent is unreachable (2) AND we are configured to use Proton Pass, try to fix it
        if [ $agent_status -eq 2 ] && [ "$SSH_AUTH_SOCK" = "$PROTON_PASS_AGENT_SOCK" ]; then
            echo "Proton SSH Agent is unreachable. Triggering proton-pass-cli-autologin.service..." >&2
            systemctl --user start proton-pass-cli-autologin.service
            
            echo "Retrying SSH connection..." >&2
            command ssh "$@"
            return $?
        fi
    fi
    return $ssh_exit
}
