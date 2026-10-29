# Headless agent profile

Use `stow -n -t ~ common agent`, then `stow -t ~ common agent`.
This is an alternative to `personal` and `steamos`, not an additional
persona. It does not install desktop applications or apply `root/`.

- Preserve user-local CLI paths alongside common's Homebrew setup.
- Disable automatic bulk secret rendering with `DOTFILES_SCOPED_AGENT=1`.
  In non-interactive shells, load `agent/.bashrc.d/00-agent.bash` (or export
  `DOTFILES_SCOPED_AGENT=1`) before `common/.bashrc.d/secrets.bash`.
  Verify `pass-cli info`, set a short
  `PROTON_PASS_AGENT_REASON`, and render only the required selector. Never print
  generated files or commit them. The manual renderer remains unchanged.
- Use the existing scoped Proton session. Do not enable the desktop keyring
  auto-login services on a headless host; their helper needs a desktop
  keyring (`secret-tool`) and desktop notifications.
- Resolve GitHub's credential helper through PATH.
- Disable inherited personal SSH commit signing until an authorized signing
  identity is provisioned for the agent. Do not export a private key for this.
- Retain the shared `~/.agents/skills` checkout and the separate private context;
  this profile does not copy, overwrite, or publish either.

Common's desktop configs are linked but dormant on a headless machine.

MCP servers come from the MCPorter registry: render only an authorized
selector for `~/.mcporter/mcporter.json`, then use the `mcporter` CLI or the
`mcporter-mcp` bridge. Dotfiles ship no Codex config; a host's
`~/.codex/config.toml` is local and never touched by stow or `update-dotfiles`.

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
to disable them. Both run the pinned skills.sh CLI (`skills add
luckycold/agent-skills --global --yes`), using Node.js from `PATH` or mise
(including `~/.local/share/agent-tools/bin/mise`); a host with neither gets a
hint, keeps its installed skills, and `update-dotfiles --yes` reports a warning
rather than a failure. Each automatic update has a 120-second
timeout, with forced termination after a further 5 seconds; it is skipped if
neither `timeout` nor `gtimeout` is installed. `update-dotfiles --yes` also runs
`update-agent-skills`, the explicit command, which has no automatic timeout.

Agents connect over non-interactive SSH, so they should run
`source ~/dotfiles/common/.bashrc.d/dotfiles_management.bash && update-dotfiles --yes`.
Sourcing the file in a non-interactive shell no longer starts the background
`git fetch`, and both fetches share a lock, so the old "cannot lock ref" race
and the `_DOTFILES_CHECKED=1` workaround are gone. If git reports "dubious
ownership", `update-dotfiles` says so and suggests a `chown` instead of
failing silently.
