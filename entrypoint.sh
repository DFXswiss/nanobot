#!/bin/sh
set -e

# Validate required environment variables
: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is required}"
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is required}"
: "${TELEGRAM_USER_IDS:?TELEGRAM_USER_IDS is required (use * for public)}"
# GH_TOKEN is optional — instances that don't interact with GitHub can omit it.

MOUNT_DIR="/root/.nanobot"
DEFAULTS_DIR="/opt/nanobot/defaults"

mkdir -p "$MOUNT_DIR/workspace"

# Build JSON array from comma-separated user IDs
ALLOW_FROM=$(echo "$TELEGRAM_USER_IDS" | tr ',' '\n' | jq -R . | jq -s .)

# Configurable tool settings (override via environment)
MCP_PATH="${MCP_FILESYSTEM_PATH:-$MOUNT_DIR/workspace}"
EXEC_TOOL="${EXEC_ENABLED:-true}"

# Build tools object conditionally (exec can be disabled for public-facing bots)
if [ "$EXEC_TOOL" = "true" ]; then
  TOOLS_EXEC='{"timeout":300}'
else
  TOOLS_EXEC='null'
fi

# Optional MCP servers in addition to the built-in filesystem server.
# Format: a JSON object, e.g.
#   MCP_EXTRA_SERVERS='{"normen": {"url": "http://rag:8765/mcp"}}'
# Passed through verbatim into tools.mcpServers (merged, filesystem wins on collision).
EXTRA_MCP_SERVERS="${MCP_EXTRA_SERVERS:-{\}}"
# Validate — fail fast if the caller supplied something that isn't valid JSON.
echo "$EXTRA_MCP_SERVERS" | jq -e type > /dev/null || {
  echo "MCP_EXTRA_SERVERS is not valid JSON: $EXTRA_MCP_SERVERS" >&2
  exit 1
}

# Generate config.json from environment variables (jq ensures valid JSON)
jq -n \
  --arg api_key "$ANTHROPIC_API_KEY" \
  --arg tg_token "$TELEGRAM_BOT_TOKEN" \
  --argjson tg_users "$ALLOW_FROM" \
  --arg mcp_path "$MCP_PATH" \
  --arg model "${AI_MODEL:-anthropic/claude-opus-4-6}" \
  --argjson exec_tool "$TOOLS_EXEC" \
  --argjson extra_mcp "$EXTRA_MCP_SERVERS" \
  '{
    providers: { anthropic: { apiKey: $api_key } },
    agents: {
      defaults: {
        model: $model,
        maxTokens: 8192,
        temperature: 0.1,
        maxToolIterations: 100,
        contextWindowTokens: 200000
      }
    },
    tools: ({
      restrictToWorkspace: true,
      mcpServers: ($extra_mcp + {
        filesystem: {
          command: "mcp-server-filesystem",
          args: [$mcp_path]
        }
      })
    } + if $exec_tool != null then { exec: $exec_tool } else {} end),
    channels: {
      telegram: {
        enabled: true,
        token: $tg_token,
        allowFrom: $tg_users
      }
    },
    gateway: { host: "0.0.0.0", port: 18790 }
  }' > "$MOUNT_DIR/config.json"

# Configure GPG commit signing
if [ -n "$GPG_PRIVATE_KEY" ]; then
  echo "$GPG_PRIVATE_KEY" | gpg --batch --import 2>/dev/null
  KEY_ID=$(gpg --list-secret-keys --keyid-format long 2>/dev/null | grep '^sec' | head -1 | sed 's/.*\/\([A-F0-9]*\) .*/\1/')
  if [ -n "$KEY_ID" ]; then
    git config --global user.signingkey "$KEY_ID"
    git config --global commit.gpgsign true
    git config --global tag.gpgsign true
    git config --global gpg.program gpg
  fi
fi

# Copy workspace files from operator profile (if mounted via BOT_PROFILE_DIR)
# or fall back to the image's placeholder defaults.
PROFILE_SRC="$DEFAULTS_DIR/workspace"
if [ -n "${BOT_PROFILE_DIR:-}" ] && [ -d "$BOT_PROFILE_DIR" ]; then
  PROFILE_SRC="$BOT_PROFILE_DIR"
fi
cp -r "$PROFILE_SRC"/* "$MOUNT_DIR/workspace/" 2>/dev/null || true

exec nanobot "$@"
