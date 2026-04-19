# NanoBot — AI Assistant

Always-on AI assistant running in Docker, connected via Telegram.

## Architecture

NanoBot runs `nanobot gateway` inside a Docker container, maintaining an outbound WebSocket to Telegram. A named volume mounted at `/root/.nanobot` holds persistent workspace data (cloned repos, session state). Multiple instances can run side by side — one Compose service per bot.

## Prerequisites

- Docker + Docker Compose
- Docker Hub push access for the image registry used
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
| `AI_MODEL` | Optional: override default model (`anthropic/claude-opus-4-6`) |
| `GPG_PRIVATE_KEY` | Optional: ASCII-armored private key for commit signing |

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

## Deployment

Image build and deploy are decoupled:

1. The GitHub Actions workflow (`.github/workflows/deploy.yml`) builds `nanobot:<sha>` and `nanobot:latest`, pushes to the configured registry, then triggers a `repository_dispatch` at the downstream infrastructure repo so it can pull the new image and restart.
2. The downstream repo is responsible for the Compose stack and per-instance `.env` files — this repo has no deployment targets hard-coded.

## CI/CD

The workflow triggers on:
- Push to `main` that changes `Dockerfile`, `entrypoint.sh`, `workspace/`, or the workflow itself
- Manual dispatch

**Required GitHub Secrets:**
- `DOCKER_USERNAME` / `DOCKER_PASSWORD` — registry push access
- `DISPATCH_REPO` — downstream repo (`owner/name`) to notify on image push
- `DISPATCH_TOKEN` — PAT with `repo` scope on `DISPATCH_REPO`

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
- `.env` is in `.gitignore`
- `GH_TOKEN` is a classic PAT scoped to `repo`, `workflow`, `read:org`
- NanoBot version and GitHub Actions are pinned in `Dockerfile` and workflows
