# Headless agent profile

Use `stow -n -t ~ common agent`, then `stow -t ~ common agent`.
This is an alternative to `personal`, `work`, and `steamos`, not an additional
persona. It does not install desktop applications or apply `root/`.

- Preserve user-local CLI paths alongside common's Homebrew setup.
- Disable automatic bulk secret rendering. Load `common/.bashrc.d/secrets.bash`
  explicitly in non-interactive shells, verify `pass-cli info`, set a short
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

## Updating this profile

`update-dotfiles` recognizes `agent` as an active profile and skips bulk secret
rendering, including during non-interactive updates. Interactive profile changes
on other profiles offer one refresh, rather than running it twice.

When the scoped CLI wrapper and its session directory are already provisioned,
new agent shells select that filesystem-backed session. No login credentials are
stored in this profile. Verify access with `pass-cli info`.

`update-agent-skills` preserves a symlink to a clean contributor checkout of
`luckycold/agent-skills` and updates it with `git pull --ff-only`. Dirty or
diverged checkouts are not overwritten, and unrelated symlinks remain protected.
