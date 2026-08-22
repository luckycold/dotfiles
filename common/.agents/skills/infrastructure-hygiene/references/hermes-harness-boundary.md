# Hermes Code Harness Boundary Incident (May 2026)

## Context
During a provider switch to grok-4.3 via xai-oauth, the agent made local modifications to core Hermes files to fix encrypted reasoning state handling and MCP bridge issues.

## Files Modified (incorrectly)
- agent/codex_responses_adapter.py
- agent/chat_completion_helpers.py
- Added test_codex_xai_oauth_recovery.py
- Various MCP bridge and s6 service patches

## User Feedback
- "Why do you keep modifying things in such a hacky way?"
- "I never want you to modify the code harness for Hermes."
- "It was designed in a certain way for a reason."
- "I never want you to do this kind of thing again."
- Explicit instruction to revert and use clean updates only.

## Resulting Rule
The Hermes code harness is strictly off-limits for modifications. Any needed changes must go through official channels or fresh sessions. Redundant or leftover installations discovered during work must be cleaned up immediately.

This incident established the strong boundary captured in the parent skill.
