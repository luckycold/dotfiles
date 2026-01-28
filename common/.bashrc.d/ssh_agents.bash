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
            echo "Proton SSH Agent is unreachable. Restarting proton-pass-cli-autologin.service..." >&2
            
            # Check if systemd is available
            if ! command -v systemctl >/dev/null 2>&1; then
                echo "systemctl not found, cannot restart service" >&2
                return $ssh_exit
            fi

            # Restart the service
            if ! systemctl --user restart proton-pass-cli-autologin.service 2>&1; then
                echo "Failed to restart service" >&2
                return 1
            fi

            # Wait for agent to be ready (up to 30s with status updates)
            echo "Waiting for SSH agent socket..." >&2
            for i in $(seq 1 30); do
                # Check if service failed
                local svc_state
                svc_state=$(systemctl --user show -p ActiveState --value proton-pass-cli-autologin.service 2>/dev/null)
                if [ "$svc_state" = "failed" ]; then
                    echo "Service failed. Check: journalctl --user -u proton-pass-cli-autologin.service" >&2
                    return 1
                fi

                # Check if socket is ready
                if [ -S "$PROTON_PASS_AGENT_SOCK" ]; then
                    ssh-add -l >/dev/null 2>&1
                    local check=$?
                    if [ $check -le 1 ]; then
                        echo "SSH agent ready. Retrying connection..." >&2
                        command ssh "$@"
                        return $?
                    fi
                fi

                printf "." >&2
                sleep 1
            done
            echo "" >&2
            echo "Timeout waiting for SSH agent. Check: systemctl --user status proton-pass-cli-autologin.service" >&2
            return 1
        fi
    fi
    return $ssh_exit
}
