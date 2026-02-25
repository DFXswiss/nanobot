# NanoBot — DFX AI Assistant

Always-on AI assistant running in Azure Container Apps, connected via Telegram.

## Architecture

```
Existing DFX Infrastructure (reused)         New (NanoBot-specific)
─────────────────────────────────────         ─────────────────────
rg-dfx-api-prd   (Resource Group)       →    ca-dfx-nbt-prd   (Container App)
cae-dfx-api-prd  (Container Apps Env)   →    ca-nbt            (File Share)
stdfxapiprd      (Storage Account)      →    share-dfx-nbt-prd (Env Storage Link)
Docker Hub (dfxswiss/*)                 →    dfxswiss/nanobot   (Docker Hub image)
```

NanoBot runs `nanobot gateway` (port 18790), maintains outbound WebSocket to Telegram. No inbound traffic needed, but ingress is configured (the shared Bicep module hardcodes `external: true`).

## Prerequisites

- Azure subscription with access to `rg-dfx-api-prd`
- Docker Hub `dfxswiss` organization access
- Telegram bot token (from @BotFather)
- Anthropic API key
- GitHub PAT with `repo` scope

## Configuration

### config.json

Copy `config.example.json` and fill in real secrets. Key sections:

- **providers** — API keys (uses camelCase: `apiKey`, not `api_key`)
- **agents.defaults** — model, token limits, temperature, tool iterations, memory window
- **tools** — MCP servers and workspace restrictions
- **channels** — Telegram bot token and user allowlist
- **gateway** — host/port for the gateway server

System prompts are configured via workspace markdown files (see below), not in config.json.

### Workspace files

NanoBot assembles system prompts from markdown files in the workspace directory (`/root/.nanobot/workspace/`):

| File | Purpose |
|------|---------|
| `SOUL.md` | Agent personality and behavior guidelines |
| `USER.md` | User context (optional) |
| `AGENTS.md` | Role definitions (optional) |

A default `SOUL.md` is baked into the Docker image. To customize, upload your own to the Azure file share.

## Local Development

```bash
# 1. Copy and fill in secrets
cp config.example.json ~/.nanobot/config.json   # edit with real API keys
cp .env.example .env                             # edit with real GitHub PAT

# 2. (Optional) customize workspace personality
cp workspace/SOUL.md ~/.nanobot/workspace/SOUL.md   # edit as needed

# 3. Build and run
docker compose up -d gateway
docker compose logs -f gateway

# 4. Test: send a message to your bot on Telegram

# 5. Run CLI commands against the running instance
docker compose run --rm cli status
```

## Azure Deployment

### Step 1: Build and Push Docker Image

```bash
docker build -t dfxswiss/nanobot:latest .
docker push dfxswiss/nanobot:latest
```

### Step 2: Create File Share

1. Portal → Storage accounts → `stdfxapiprd`
2. Left menu → File shares → + File share
3. Name: `ca-nbt`, Tier: Transaction optimized, Quota: 10 GiB
4. Click Create

### Step 3: Upload config.json and workspace files

Prepare `config.json` from `config.example.json` with real API keys and Telegram token.

**Via Portal:**
1. Open `ca-nbt` file share
2. Upload `config.json` to the root
3. Create a `workspace` directory and upload `SOUL.md` into it

**Via CLI:**
```bash
az storage file upload \
  --account-name stdfxapiprd \
  --account-key <KEY> \
  --share-name ca-nbt \
  --source ./config.json \
  --path config.json

az storage directory create \
  --account-name stdfxapiprd \
  --account-key <KEY> \
  --share-name ca-nbt \
  --name workspace

az storage file upload \
  --account-name stdfxapiprd \
  --account-key <KEY> \
  --share-name ca-nbt \
  --source ./workspace/SOUL.md \
  --path workspace/SOUL.md
```

### Step 4: Link Storage to Container Apps Environment

1. Portal → Container Apps Environments → `cae-dfx-api-prd`
2. Left menu → Settings → Azure Files
3. \+ Add:
   - Name: `share-dfx-nbt-prd`
   - Storage account: `stdfxapiprd`
   - Storage account key: (copy from storage account → Access keys)
   - File share: `ca-nbt`
   - Access mode: Read/Write
4. Save

### Step 5: Create Container App

1. Portal → Container Apps → + Create
2. **Basics tab:**
   - Resource group: `rg-dfx-api-prd`
   - Name: `ca-dfx-nbt-prd`
   - Region: (same as environment)
   - Container Apps Environment: `cae-dfx-api-prd`
3. **Container tab:**
   - Uncheck "Use quickstart image"
   - Image source: Docker Hub or other registries
   - Image: `dfxswiss/nanobot:latest`
   - CPU: 1, Memory: 2 Gi
   - Environment variables:
     - `GH_TOKEN` = (your GitHub PAT)
4. **Ingress tab:**
   - Ingress: Enabled
   - Ingress traffic: Accept from anywhere
   - Target port: 18790
5. **Scale tab:**
   - Min replicas: 1, Max replicas: 1
6. Review + Create

### Step 6: Add Volume Mount

1. Go to `ca-dfx-nbt-prd` → Application → Containers
2. Click "Edit and deploy" → create new revision
3. **Volumes tab** → + Add:
   - Volume type: Azure file volume
   - Name: `volume`
   - File share name: `share-dfx-nbt-prd`
   - Mount options: `nobrl,cache=none`
4. **Container image** → Edit → Volume mounts:
   - Volume name: `volume`
   - Mount path: `/root/.nanobot`
5. Click Create (creates new revision with volume mount)

### Step 7: Verify

```bash
az containerapp logs show -n ca-dfx-nbt-prd -g rg-dfx-api-prd --follow
```

Look for: `Starting nanobot gateway...` and `Telegram channel enabled`.

Send a test message to your bot on Telegram.

### Alternative: Deploy via Bicep

```bash
cd /path/to/api/infrastructure/bicep/container-apps/apps/
./deploy.sh    # Select: prd → nbt
```

## GitHub Access

Create a dedicated machine user account (e.g., `dfx-nanobot`) on GitHub:

1. Create a new GitHub account for the bot
2. Add it to the DFX org as a member
3. Grant it access to the repos it should work on
4. Generate a **classic PAT** with scopes: `repo`, `workflow`, `read:org`

The PAT goes into the `GH_TOKEN` env var in the Container App.

## CI/CD

The GitHub Actions workflow (`.github/workflows/deploy.yml`) triggers on:
- Push to `main` that changes `Dockerfile` or the workflow itself
- Manual dispatch

**Required GitHub Secrets:**
- `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` — Docker Hub push access
- `AZURE_CREDENTIALS` — Service principal JSON (same pattern as other DFX repos)

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
| Azure Files (10 GB) | ~$0.50 |
| Docker Hub (free tier) | $0 |
| **Total (excl. API)** | **~$10-15** |

## Security Checklist

- [ ] `allowFrom` on Telegram channel is non-empty (whitelist user IDs)
- [ ] `restrictToWorkspace: true` in config
- [ ] `config.json` never committed to git
- [ ] `.env` in `.gitignore`
- [ ] Dedicated GitHub machine user with scoped access
- [ ] `GH_TOKEN` is a classic PAT with scopes: `repo`, `workflow`, `read:org`
- [ ] Docker Hub creds stored as GitHub Secrets only
- [ ] Azure service principal scoped to `rg-dfx-api-prd`
- [ ] Anthropic API key has usage limits set
- [ ] NanoBot version pinned in Dockerfile
