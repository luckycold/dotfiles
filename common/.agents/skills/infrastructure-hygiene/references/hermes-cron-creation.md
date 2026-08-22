# Hermes Cron Job Creation for Hygiene, Monitoring, and Maintenance Tasks

Luke's stack uses the `hermes` CLI subcommand (not the generic top-level `cronjob` tool) to create scheduled jobs that run fresh agent sessions with attached skills and self-contained prompts.

## Correct Creation Command

```bash
# From the active hermes binary (usually in the venv or PATH)
export PATH=/config/.hermes/hermes-agent/venv/bin:$PATH

hermes cron create "SCHEDULE" "PROMPT" \
  --name "job-name" \
  --deliver local \
  --skill skill1 --skill skill2 \
  --workdir /config \
  --profile default
```

- `SCHEDULE`: standard 5-field cron (e.g. "0 8 * * *" for daily 8 a.m., "0 4 * * 0" for weekly Sunday 4 a.m.).
- `PROMPT`: the full self-contained instruction text (or `$(cat /tmp/prompt.txt)`). The agent that executes at schedule time has no prior conversation context.
- `--deliver local`: recommended for background/hygiene jobs whose primary user-visible action is conditional (e.g. NTFY only on important findings). Prevents flooding the main Telegram channel with "nothing to report" messages every day.
- `--skill`: explicitly list every skill the prompt will rely on. The scheduler loads them for the fresh run.
- `--workdir` and `--profile`: usually /config and default for the main Hermes container.

After creation, immediately verify:

```bash
hermes cron list
```

Look for the new job_id, next_run_at, skills list, deliver mode, and last_status.

## Common Patterns Observed

- Weekly tooling/maintenance: "0 4 * * 0", skill "hermes-agent", deliver origin.
- Proton Pass SSH agent watchdog: minutely script mode (`--script ... --no-agent`).
- Morning email importance scan: "0 8 * * *", multiple skills (himalaya + proton-pass-cli + truenas-custom-apps), deliver local, self-contained prompt that only notifies on signal.

## Key Lessons / Pitfalls

- Do **not** use the generic `cronjob` tool (the one exposed as a top-level tool) for Hermes skill-attached jobs. It expects different parameters and will repeatedly fail with messages like "schedule is required for create" when you try to pass prompts or --skill flags. Use the `hermes cron create` subcommand instead.
- Self-contained prompts are mandatory. Any reference to "the conversation so far" or prior tool results will be empty in the cron session.
- For jobs that should be quiet by default (e.g. "surface only if important"), combine `deliver=local` with conditional notification logic inside the prompt (NTFY curl + selective `send_message` tool calls).
- Attach the exact skills needed for the domain (email/bridge jobs need himalaya + proton-pass-cli + truenas-custom-apps).
- Existing jobs must not be disrupted; always list first and choose a distinct --name.
- The scheduler stores jobs under the active profile; cross-profile jobs require explicit `--profile`.

## When to Create a New Cron

Use for recurring hygiene, monitoring, or maintenance that the user has explicitly requested (see the "Do not create/modify cron jobs during maintenance runs unless Luke explicitly asks" rule in the parent skill). The morning email scan is a canonical example: daily 8 a.m. run, conservative filter, NTFY only on important mail.

See the `himalaya` skill references (`automated-email-importance-scans.md` and `proton-pass-agent-wrapper-for-himalaya.md`) for a complete worked example of prompt content, bridge/tunnel handling, and wrapper usage inside a cron.

## Verification & Management

- List: `hermes cron list`
- The job will appear with its job_id (e.g. dd7fca557a37), next run time, and attached skills.
- Logs / final responses from runs are delivered according to the --deliver setting (local = internal only).

This pattern keeps infrastructure maintenance conventional, auditable, and low-noise.