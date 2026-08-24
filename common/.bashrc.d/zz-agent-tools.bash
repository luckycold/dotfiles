# Host-local agent CLI paths (not part of the Stow package)
export PATH="/root/.local/bin:/root/.local/share/agent-tools/bin:/root/.grok/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PROTON_PASS_SESSION_DIR="/root/.local/share/proton-pass-cli/agent-session"
export PROTON_PASS_KEY_PROVIDER=fs
export PROTON_PASS_DISABLE_TELEMETRY=1
export PASS_LOG_LEVEL=warn
if [ -d "/root/.local/share/codex" ]; then
  export CODEX_HOME="/root/.local/share/codex"
fi
