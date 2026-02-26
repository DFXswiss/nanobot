# NanoBot — DFX AI Assistant

Always-on AI assistant running in Azure Container Apps, connected via Telegram.

## Architecture

NanoBot runs `nanobot gateway` (port 18790) in an Azure Container App, maintaining an outbound WebSocket to Telegram. An Azure file share is mounted for persistent workspace data (cloned repos, session state).

## Prerequisites

- Azure Container Apps environment
- Docker Hub organization access
- Telegram bot token (from @BotFather)
- Anthropic API key
- GitHub PAT with `repo` scope

## Configuration

All configuration is driven by environment variables. The entrypoint script generates `config.json` and copies workspace files automatically at startup.

| Env var | Purpose |
|---------|---------|
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token (from @BotFather) |
| `TELEGRAM_USER_ID` | Telegram user ID to allow (from @userinfobot) |
| `GH_TOKEN` | GitHub PAT for `gh` CLI |

### Workspace files

System prompts are assembled from markdown files in `workspace/`:

| File | Purpose |
|------|---------|
| `SOUL.md` | Agent personality and behavior guidelines |
| `USER.md` | User context (optional) |
| `AGENTS.md` | Role definitions (optional) |

These are baked into the image and auto-deployed on each restart. Edit them in git and push to update.

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

## Azure Deployment

### Step 1: Build and Push Docker Image

```bash
docker build -t dfxswiss/nanobot:latest .
docker push dfxswiss/nanobot:latest
```

### Step 2: Azure Setup

One-time setup: create the container app, mount a file share at `/root/.nanobot`, and set the environment variables listed above. See internal documentation for resource names.

### Step 3: Verify

Check the container logs for `Starting nanobot gateway on port 18790...` and `Telegram channel enabled`. Then send a test message to your bot on Telegram.

## CI/CD

The GitHub Actions workflow (`.github/workflows/deploy.yml`) triggers on:
- Push to `main` that changes `Dockerfile`, `entrypoint.sh`, `workspace/`, or the workflow itself
- Manual dispatch

**Required GitHub Secrets:**
- `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` — Docker Hub push access
- `AZURE_CREDENTIALS` — Service principal JSON

**Required GitHub Variables:**
- `AZURE_CONTAINER_APP` — Container App name
- `AZURE_RESOURCE_GROUP` — Resource group name

## Tools

| Tool | How | Notes |
|------|-----|-------|
| Filesystem | MCP server (`@modelcontextprotocol/server-filesystem`) | Scoped to workspace |
| GitHub | `gh` CLI via shell | Authenticated via `GH_TOKEN` env var |
| Browser | Playwright via shell | Headless Chromium in container |
| Web search | NanoBot built-in | Included out of the box |
| Shell | NanoBot built-in | Included out of the box |

## Resources

| Component | Monthly Cost |
|-----------|-------------|
| Container App (1 vCPU, 2 GiB) | ~$10-15 |
| Azure Files (50 GB) | ~$2.50 |
| Docker Hub (free tier) | $0 |
| **Total (excl. API)** | **~$10-15** |

## Security Checklist

- [ ] All secrets are env vars on the container app (never in git)
- [ ] `.env` in `.gitignore`
- [ ] Dedicated GitHub machine user with scoped access
- [ ] `GH_TOKEN` is a classic PAT with scopes: `repo`, `workflow`, `read:org`
- [ ] Docker Hub creds stored as GitHub Secrets only
- [ ] Azure service principal scoped to the resource group
- [ ] Anthropic API key has usage limits set
- [ ] NanoBot version pinned in Dockerfile
