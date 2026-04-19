# Agent Instructions

Placeholder. Operational rules (tool discipline, memory management, cron/heartbeat
usage, git workflow etc.) belong here. Override by mounting your own profile
directory via the `BOT_PROFILE_DIR` environment variable at deploy time.

## Workspace Files

`SOUL.md`, `AGENTS.md`, `TOOLS.md`, and `USER.md` together define the bot's
personality, behavior, tool constraints, and user profile. They are copied from
the active profile directory into `/root/.nanobot/workspace/` on every
container start — local edits are overwritten.

## Memory Management

- `MEMORY.md` — current facts worth remembering across sessions (operator-defined).
- `HEARTBEAT.md` — periodic tasks, polled every 30 minutes.
- `HISTORY.md` — short record of completed tasks.

Keep each file short. Long files dilute context.
