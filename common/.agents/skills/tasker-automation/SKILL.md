---
name: tasker-automation
description: Build, edit, verify, and troubleshoot Android Tasker automations, including Tasker WebUI task editing, notification-listener workflows, Java Code actions, and event-driven testing.
author: Luke
version: 1.0.0
platforms: [android, linux, macos, windows]
metadata:
  hermes:
    tags: [tasker, android, automation, notifications, webui]
    category: productivity
---

# Tasker Automation

Use this skill when creating or modifying Tasker profiles/tasks, driving Tasker's WebUI, implementing notification logic, or validating Android automations from Hermes.

## Principles

1. **Inspect the live context before editing.** Query the active task's actions and variables; do not assume which Tasker task/profile is open.
2. **Use local Tasker metadata as the schema source.** Action codes, argument IDs, types, and names vary by Tasker version. Discover them from the running WebUI instead of copying stale examples.
3. **Back up before mutation.** Save the exact `/actions` response with a timestamp.
4. **Prefer reversible edits.** Append a new action, verify the round-trip representation, then delete/replace the old action.
5. **Separate persistence verification from behavior verification.** Confirm the task structure through the API, then trigger a real event and verify the Android-side effect.
6. **Minimize state and race conditions.** For notification deduplication, scanning currently active notifications is often safer than maintaining “last notification” globals and waiting for the second app.

## Tasker WebUI discovery workflow

Given a trusted Tasker WebUI base URL:

1. Check `/ping`.
2. Read `/explore` to enumerate the version's available endpoints and request shapes.
3. Read `/actions` to identify the currently open task and preserve its existing actions.
4. Read `/variables` to infer event context variables such as `%an_package`, `%an_title`, and `%an_text`.
5. Read `/category_specs`, then `/action_specs?category_code=<code>` for exact action schemas.
6. Read `/arg_specs` if argument type semantics are unclear.

The WebUI testing page may hide large JSON in textareas or accessibility snapshots. Directly navigating to read-only endpoints or using an approved local HTTP client is usually more reliable.

## Mutation pattern

Tasker WebUI mutation requests typically use JSON bodies where `action` itself is a **stringified WebUIAction JSON object**. Confirm this from the page source or `/explore` before writing.

Recommended sequence:

1. `GET /actions` → timestamped backup.
2. `PATCH /actions` → append candidate action.
3. `GET /actions` → verify action count, code, arguments, and critical content.
4. Remove the superseded action only after the candidate round-trips successfully.
5. Save another post-change snapshot.

Do not rely on `blockProperties` surviving byte-for-byte; Tasker may normalize positional/internal fields. Verify semantic fields (`code`, `name`, argument IDs/values) instead.

## Notification automations with Java Code

Recent Tasker versions expose a **Java Code** action and a `tasker` helper. For cross-app notification work:

- Obtain Tasker's bound listener with `tasker.getNotificationListener()`.
- Handle a `null` listener explicitly.
- Read `StatusBarNotification[]` from `getActiveNotifications()`.
- Filter by exact Android package name.
- Skip `Notification.FLAG_GROUP_SUMMARY` entries unless group summaries are intentionally part of the logic.
- Compare stable notification extras, usually `Notification.EXTRA_TITLE` and `Notification.EXTRA_TEXT`.
- Normalize case, repeated whitespace, and invisible Unicode before comparison.
- Require non-empty comparison fields to avoid matching generic/blank notifications.
- Dismiss only the selected notification with `listener.cancelNotification(statusBarNotification.getKey())`.
- Use `tasker.showToast(...)` for user-visible confirmation.

This active-scan design handles either arrival order: when the second app posts its copy, both notifications are present and the preferred one can be removed by key.

## Verification checklist

- [ ] WebUI `/actions` returns the intended action exactly once.
- [ ] Package IDs and cancellation target are explicit.
- [ ] Group summaries and empty fields are guarded.
- [ ] The code handles missing notification-listener access.
- [ ] A real event is generated (for mail, a uniquely titled self-email works well).
- [ ] Upstream delivery is independently confirmed when possible.
- [ ] On-device result is checked: retained notification, dismissed notification, and toast.
- [ ] If the observed WebUI version does not advertise execution/log endpoints in `/explore`, report that observability boundary rather than claiming full end-to-end verification.

## Pitfalls

- **Wrong cancellation action:** Tasker's built-in `Notify Cancel` normally targets notifications created by Tasker, not arbitrary third-party app notifications. Use the notification-listener service for other apps.
- **Arrival-order race:** Storing only the immediately previous notification fails when apps deliver in the opposite order or with delay. Scan active notifications instead.
- **Matching on IDs:** Different apps assign unrelated notification IDs. Compare semantic content and cancel by the target app's notification key.
- **Over-broad matching:** Title-only matching can remove unrelated messages from the same sender. Start with normalized title + text and tune only after collecting diagnostics.
- **Group summaries:** Mail apps may emit both child and summary notifications; summaries can produce false duplicates.
- **Unsaved Tasker editor state:** When behavior does not trigger after a successful API edit, verify the active Tasker editor has committed/backed out to save and that the profile is enabled.
- **Persistence is not execution:** A valid `/actions` response proves configuration, not that Android executed it without runtime errors.

## References

- `references/webui-notification-dedup.md` — concrete WebUI request shape, notification deduplication recipe, known package IDs, and validation strategy.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update its canonical package under `~/.agents/skills/` when a verified reusable correction, user correction, or repeatable workflow would improve future runs. Make the smallest evidence-backed edit, do not record secrets or transient state, and do not infer a durable preference from one request. Follow the `personal-skill-maintenance` skill for the full review and verification workflow.
