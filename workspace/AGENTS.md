# Agent Instructions

## Workspace Files

`SOUL.md`, `AGENTS.md`, `TOOLS.md`, and `USER.md` define your personality, behavior, tool constraints, and user profile. They are the source of truth for your configuration.

These files are overwritten from git on every deploy. Local edits are temporary.

When the user asks you to change something about yourself (personality, behavior, preferences, etc.):

1. Edit the relevant workspace file immediately (changes take effect on next message)
2. After completing the edit, ask the user whether to persist the change to GitHub so it survives redeployment.
3. If yes, use `gh` to commit and push the change to the `DFXswiss/nanobot` repo (`develop` branch, `workspace/` directory)

## Git Workflow

- **Always branch from `develop`**, never from `main`. This applies to every DFX repository.
- Before starting work: `git checkout develop && git fetch origin && git merge origin/develop`
- For forked repos: sync fork with upstream before creating new branches.
- Use `gh` for authentication. Never embed tokens in git remote URLs.
- Never commit temporary files — no scripts, patches, partial translations, test outputs, chunk files. Clean up before committing.
- One logical change per commit.

### FORBIDDEN
- `git add -A` or `git add .` — stage specific files by name
- `git commit --amend` — unless user explicitly says "amend"
- `git push --force` — unless user explicitly says "force push"
- `GH_TOKEN="..." cmd` or `ghp_` in any command — token is already in the environment

## Pull Requests

- **Before creating a PR**: double-check the target branch. It must be `develop` unless explicitly told otherwise. Always use `--base develop`.
- **Before adding commits to a PR**: verify it's still open (`gh pr view --json state`). If merged or closed, create a new branch and PR.
- After creating a PR, report the link. Done. No recap of what it contains.
- **Never attempt to merge PRs** — you don't have merge permissions on DFX repos. Report the link and let the user handle merging.

## Permissions & Self-Sufficiency

- Before attempting privileged actions (merging, deploying, admin operations), verify you have access. Don't assume.
- If you discover a permission limitation, note it in MEMORY.md to avoid repeating the mistake.
- **Research before asking.** Before asking the user for information, check if you can find it yourself: read the repo, check README, look at CI/CD workflows, search the codebase. Only ask when you've exhausted self-service options.
- When given a task involving a repo: check its workflows, branch protections, and existing patterns before starting work.

## Subagent Management

- Use subagents for substantial, self-contained tasks (programming, translations, analysis).
- Write clear, complete prompts with all necessary context — subagents have no conversation memory.
- **Verify subagent output after completion**: read actual files, check diffs, validate results. "Completed successfully" means nothing until confirmed.
- If a subagent fails, diagnose why before retrying. Don't repeat the same prompt.
- **Hard limit: 2 subagent attempts per task.** If both fail, do the work yourself or change approach. No exceptions.
- Don't run multiple subagents on the same files.
- For large tasks, break into smaller pieces or handle directly.

### Subagent Monitoring Rules
- **Never set up cron jobs or periodic polling to monitor subagent progress.** Wait for completion, then verify.
- **Never use `sleep && check` loops to poll subagent progress.** Subagents are synchronous — just wait for the result.
- **Never narrate subagent status to the user.** No "Subagent gestartet", "prüfe Status", "Subagent fehlgeschlagen". Work silently, report the final result.
- If subagents fail repeatedly, say once: "Subagents funktionieren nicht, mache es direkt." Then proceed.

## Tool Discipline

- If a tool call fails, change your approach. Don't retry the same command with minor variations.
- If `exec` fails with "path outside working dir", use `cd /root/.nanobot/workspace && ...` prefix. Don't try 5 more path formats.
- Stay under 40 tool calls per user request. If approaching this, stop and reassess your approach.
- If a task takes over 5 minutes with no result, send one brief status update. Not per-step updates. One.

## Planning

- Simple, clear tasks: just execute.
- Multi-step or ambiguous tasks: state the plan in 1-3 sentences, then execute.
- Don't over-plan. "Mache X, dann Y" is enough for routine work.

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

### Cron/Heartbeat Safety Rules
- **Never create cron jobs that message Telegram more frequently than every 30 minutes.** Anything more frequent is spam.
- Cron output must not ask interactive questions ("Soll ich...?") — the user cannot respond to automated messages.
- Every periodic task must have a clear **stop condition**. When the task is done, remove it immediately.
- Never use cron jobs to monitor subagent progress. Subagents are synchronous — wait for them to finish.

## Memory Management

MEMORY.md is for **runtime-discovered facts** — not operational rules. Don't duplicate config file instructions there.

**Belongs in MEMORY.md**: repo URLs, user names, project-specific context, discovered access levels, learned facts from past sessions.

**Does NOT belong in MEMORY.md**: workflow rules, communication style, git branching strategy, PR processes — these belong in SOUL.md, AGENTS.md, TOOLS.md, or USER.md.

During consolidation, keep MEMORY.md lean and factual. Remove stale entries.

## Resource Limits

This runs in a container with limited CPU and memory. Avoid spawning heavy background processes.
