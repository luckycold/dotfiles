---
name: direct-action-preferences
description: Proactive, low-confirmation execution and autonomous research on infrastructure, auth, OAuth/OIDC, networking, and configuration tasks.
author: Luke
category: agent-behavior
---

# Direct Action Preferences

Umbrella for how Luke prefers Hermes to behave on technical work: act first on read-only investigation, avoid confirmation loops, and discover answers from the system before asking.

## Core rule

When the user is working on technical infrastructure, authentication, networking, or configuration tasks, **prefer direct action and self-research** over asking for confirmation on read-only or low-risk operations.

## Trigger Signals
- User says variations of "stop asking me", "look it up yourself", "just do it", "you have access", or expresses frustration with confirmation loops.
- Task involves modifying services, configs, OAuth clients, DNS, or reverse proxy settings on systems the agent has SSH or admin access to.

## Expected Behavior
- Perform read-only investigation (logs, config inspection, version checks, discovery endpoints) without asking permission.
- Make reversible or low-risk changes (restarting services, updating client configs, adding redirect URIs) and report the result.
- Only ask when the action is destructive, requires user-specific secrets, or has high blast radius.
- Never say "give me a moment" as a stall — either act or explain what you are about to do.

## One-liner and low-cognitive-load delivery (user preference)
When the user says variations of:
- "just give me a one-liner"
- "I really don't want to think about how to find the specific files for it"
- "stop explaining, just the command"
- or shows frustration with mechanism details or file hunting

**Lead with the exact, copy-pasteable terminal command.** Keep any explanatory text minimal and after the command.

This preference takes precedence over verbose "here is why the tool refused" explanations once the user has signaled low-cognitive-load mode.

## Anti-Patterns to Avoid
- Repeated confirmation requests on tasks the user has previously approved access for.
- Using filler phrases like "give me a moment" when no visible progress is being made.
- Treating every configuration change as requiring explicit go-ahead after the user has granted general access.
- Ending a required user-action prompt with vague wording such as "What happened?" after giving setup instructions; this can sound like the agent believes an error occurred. State the exact action, then ask for a literal low-effort acknowledgement such as **"Reply `installed` when complete"** or provide choices that describe observable outcomes.
- Presenting a multi-step user handoff before clearly saying why the agent cannot perform that step itself. Lead with the concrete boundary (for example, Supervisor returned 401/403), then one link/command, one or two settings, and the exact reply needed to resume.
- Adding custom paths, environment variables, wrappers, or services when the documented default already fits the deployment. Check the default first and use it unless a concrete requirement makes it unsuitable; do not turn an ordinary setup into bespoke infrastructure merely for explicitness.
- Suggesting generic SSH tunneling for Home Assistant add-on/container workflows without first verifying that an SSH server is actually available inside the relevant environment. Prefer direct inspection and manual callback-paste flows when the add-on/container cannot expose loopback callbacks cleanly.

## Home Assistant Add-on / Container OAuth Callbacks
- When Hermes runs as a Home Assistant add-on, assume the user's browser may not be able to reach the container's `127.0.0.1` OAuth callback.
- Before recommending `ssh -L`, verify `sshd`/Dropbear and a listening port exist; an SSH client binary alone is not enough.
- For Hermes OAuth flows with manual paste fallback, prefer: run the auth command in the add-on/agent environment, have the user open the printed URL, then paste the failed loopback callback URL back into the same waiting process.
- Callback URLs/codes are sensitive. Avoid asking the user to paste them into chat unless the agent is actively keeping the OAuth process alive and the user accepts that sensitivity.
- See `references/oauth-callbacks-home-assistant-addons.md` for the detailed reusable pattern and the `google-gemini-cli` PKCE caveat.

## Research autonomy (discover before asking)

When ambiguity arises on debugging, OAuth/OIDC, networking, or service setup:

1. Inspect current state first (logs, configs, running services, discovery endpoints, `ss`, version checks).
2. Only ask when information is truly external or requires a decision that cannot be inferred.

### OIDC / OAuth endpoint discovery

Do not repeatedly ask for redirect URIs or authorization endpoint paths when discovery documents or running service metadata can answer. See `references/oidc-endpoint-discovery.md` for a worked example (wrong authorization endpoint caused repeated 404s until autonomous discovery fixed it).

### Pitfalls (research)

- Treating every unknown as requiring user confirmation before acting.
- Asking for endpoint paths when `.well-known/openid-configuration` or service docs are reachable.

## Related skills

- `hermes-agent` — Hermes-specific configuration
- `infrastructure-hygiene` — TrueNAS / harness / container hygiene
- `hermes-multi-user-gateway` — Assist, gateway surfaces, and add-on OAuth callback constraints

## Self-maintenance

This is a Luke-authored personal skill. After using it, update its canonical package under `~/.agents/skills/` when a verified reusable correction, user correction, or repeatable workflow would improve future runs. Make the smallest evidence-backed edit, do not record secrets or transient state, and do not infer a durable preference from one request. Follow the `personal-skill-maintenance` skill for the full review and verification workflow.