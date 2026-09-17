# Headless agent profile

Use `stow -n -t ~ common agent`, then `stow -t ~ common agent`.
This is an alternative to `personal`, `work`, and `steamos`, not an additional
persona. It does not install desktop applications or apply `root/`.

- Preserve user-local CLI paths alongside common's Homebrew setup.
- Disable automatic bulk secret rendering with `DOTFILES_SCOPED_AGENT=1`.
  In non-interactive shells, load `agent/.bashrc.d/00-agent.bash` (or export
  `DOTFILES_SCOPED_AGENT=1`) before `common/.bashrc.d/secrets.bash`.
  Verify `pass-cli info`, set a short
  `PROTON_PASS_AGENT_REASON`, and render only the required selector. Never print
  generated files or commit them. The manual renderer remains unchanged.
- Use the existing scoped Proton session. Do not enable the desktop keyring
  auto-login services on a headless host; their helper requires desktop keyring
  provisioning and currently passes a token in argv.
- Resolve GitHub's credential helper through PATH. OpenClaw authenticated Git
  operations still run through its managed gateway execution environment.
- Disable inherited personal SSH commit signing until an authorized signing
  identity is provisioned for the agent. Do not export a private key for this.
- Keep OpenClaw-managed runtime configuration untouched. Common's standalone
  Codex template is not the configuration of the running OpenClaw agent.
- Retain the shared `~/.agents/skills` checkout and the separate private context;
  this profile does not copy, overwrite, or publish either.

Common's desktop configs are linked but dormant on a headless machine.

## Updates

`update-dotfiles --yes` (also `-y` or `--non-interactive`) fast-forwards and
restows `common` plus the active profile, including `agent`, without prompts.
It skips bulk secret rendering for scoped agents, including when only
`common/.bashrc.d/dotfiles_management.bash` was loaded and the linked `agent`
profile is detected. Interactive updates and profile switching also skip bulk
secret rendering for scoped agents. Manual targeted rendering remains available:
`init-env-secrets <authorized-selector>`.

Automatic agent skill updates run in the locked background shell-startup job
by default, without delaying terminal startup. Set `AGENT_SKILLS_AUTO_UPDATE=0`
to disable them. The job downloads and executes npm's `skills@latest` package
(and installs Node.js through mise if needed). Each automatic update has a
120-second timeout, with forced termination after a further 5 seconds; it is
skipped if neither `timeout` nor `gtimeout` is installed. `update-dotfiles`
does not directly update skills. `update-agent-skills` remains the explicit
manual command and is not subject to the automatic timeout.
