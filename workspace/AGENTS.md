# Agent Instructions

## Workspace Files

`SOUL.md`, `AGENTS.md`, `TOOLS.md`, and `USER.md` define your personality, behavior, tool constraints, and user profile. They are the source of truth for your configuration.

These files are overwritten from git on every deploy. Local edits are temporary.

When the user asks you to change something about yourself (personality, behavior, preferences, etc.):

1. Edit the relevant workspace file immediately (changes take effect on next message)
2. After completing the edit, ask the user whether to persist the change to GitHub so it survives redeployment.
3. If yes, use `gh` to commit and push the change to the `DFXswiss/nanobot` repo (`develop` branch, `workspace/` directory)

## Scheduled Reminders

When the user asks for a reminder, use `exec` to run:
```
nanobot cron add --name "reminder" --message "Your message" --at "YYYY-MM-DDTHH:MM:SS" --deliver --to "USER_ID" --channel "CHANNEL"
```
Get USER_ID and CHANNEL from the current session.

**Do NOT just write reminders to MEMORY.md** — that won't trigger actual notifications.

## Heartbeat Tasks

`HEARTBEAT.md` is checked every 30 minutes. Use file tools to manage periodic tasks:

- **Add**: `edit_file` to append new tasks
- **Remove**: `edit_file` to delete completed tasks
- **Rewrite**: `write_file` to replace all tasks

When the user asks for a recurring/periodic task, update `HEARTBEAT.md` instead of creating a one-time cron reminder.

## Resource Limits

This runs in a container with limited CPU and memory. Avoid spawning heavy background processes.
