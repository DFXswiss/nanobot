# NanoBot — DFX AI Assistant

Always-on AI assistant running on dfx01 (Docker), connected via Telegram.

## Architecture

NanoBot runs `nanobot gateway` inside Docker on dfx01, maintaining an outbound WebSocket to Telegram. A named volume (`nanobot-<name>-data`) is mounted at `/root/.nanobot` for persistent workspace data (cloned repos, session state). Multiple instances run side by side — one Compose service per bot. The stack lives in [`DFXswiss/server`](https://github.com/DFXswiss/server) under `infrastructure/dfx01/nanobot/`.

## Prerequisites

- dfx01 with Docker (Colima)
- Docker Hub push access for `dfxswiss/nanobot`
- Telegram bot token (from @BotFather)
- Anthropic API key
- GitHub PAT with `repo` scope

## Configuration

All configuration is driven by environment variables. The entrypoint script generates `config.json` and copies workspace files automatically at startup.

| Env var | Purpose |
|---------|---------|
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token (from @BotFather) |
| `TELEGRAM_USER_IDS` | Comma-separated Telegram user IDs to allow (from @userinfobot) |
| `GH_TOKEN` | GitHub PAT for `gh` CLI |

### Workspace files

NanoBot loads these markdown files from `workspace/` into every system prompt:

| File | Purpose |
|------|---------|
| `SOUL.md` | Personality, values, communication style |
| `AGENTS.md` | Operational behavior (cron, heartbeat, resource limits) |
| `TOOLS.md` | Tool-specific constraints and safety notes |
| `USER.md` | Team profile and preferences |

These are baked into the image and copied to the persistent mount on each restart. Edit in git and deploy to update.

## Local Development

```bash
# 1. Fill in secrets
cp .env.example .env   # edit with real values

# 2. Build and run
docker compose up -d gateway
docker compose logs -f gateway

# 3. Test: send a message to your bot on Telegram

# 4. Run CLI commands against the running instance
docker compose run --rm cli status
```

## Deployment (dfx01)

Two-stage pipeline:

1. **Image build** — this repo's `deploy.yml` builds `dfxswiss/nanobot:<sha>` + `:latest`, pushes to Docker Hub, then fires a `repository_dispatch` (`event_type: dfx01-stack-redeploy`, `stack: nanobot`) at `DFXswiss/server`.
2. **Stack deploy** — the self-hosted Runner on dfx01 reacts to that event, rsyncs `infrastructure/dfx01/nanobot/` to `/Users/dfx01/docker/nanobot/`, and runs `docker compose up -d --remove-orphans`. `pull_policy: always` in the compose file ensures every instance picks up the new `:latest`.

Adding a new NanoBot instance is a commit in `DFXswiss/server` only — no change in this repo needed. See `infrastructure/dfx01/nanobot/README.md` there.

### Required GitHub Secrets (this repo)

- `DOCKER_USERNAME` / `DOCKER_PASSWORD` — Docker Hub push access (org `dfxswiss`)
- `SERVER_REPO_DISPATCH_TOKEN` — classic PAT with `repo` scope to trigger the `DFXswiss/server` workflow

## Tools

| Tool | How | Notes |
|------|-----|-------|
| Filesystem | MCP server (`@modelcontextprotocol/server-filesystem`) | Scoped to workspace |
| GitHub | `gh` CLI via shell | Authenticated via `GH_TOKEN` env var |
| Browser | Playwright via shell | Headless Chromium in container |
| Web search | NanoBot built-in | Included out of the box |
| Shell | NanoBot built-in | Included out of the box |

## Security

- All secrets are env vars on the container, never in git
- `.env` is in `.gitignore` (local dev only); dfx01 `.env` files live at `/Users/dfx01/docker/nanobot/nanobot-<name>.env`, managed by the admin, sourced from Vaultwarden
- `GH_TOKEN` is a classic PAT scoped to `repo`, `workflow`, `read:org`
- NanoBot version and GitHub Actions are pinned in `Dockerfile` and workflows
