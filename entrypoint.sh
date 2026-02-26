#!/bin/sh
set -e

# Validate required environment variables
: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is required}"
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is required}"
: "${TELEGRAM_USER_ID:?TELEGRAM_USER_ID is required}"
: "${GH_TOKEN:?GH_TOKEN is required}"

MOUNT_DIR="/root/.nanobot"
DEFAULTS_DIR="/opt/nanobot/defaults"

mkdir -p "$MOUNT_DIR/workspace"

# Generate config.json from environment variables (jq ensures valid JSON)
jq -n \
  --arg api_key "$ANTHROPIC_API_KEY" \
  --arg tg_token "$TELEGRAM_BOT_TOKEN" \
  --arg tg_user "$TELEGRAM_USER_ID" \
  --arg workspace "$MOUNT_DIR/workspace" \
  '{
    providers: { anthropic: { apiKey: $api_key } },
    agents: {
      defaults: {
        model: "anthropic/claude-sonnet-4-5",
        maxTokens: 8192,
        temperature: 0.1,
        maxToolIterations: 40,
        memoryWindow: 100
      }
    },
    tools: {
      restrictToWorkspace: true,
      mcpServers: {
        filesystem: {
          command: "mcp-server-filesystem",
          args: [$workspace]
        }
      }
    },
    channels: {
      telegram: {
        enabled: true,
        token: $tg_token,
        allowFrom: [$tg_user]
      }
    },
    gateway: { host: "0.0.0.0", port: 18790 }
  }' > "$MOUNT_DIR/config.json"

# Copy workspace defaults from image (auto-deploys updates on restart)
cp -r "$DEFAULTS_DIR/workspace/"* "$MOUNT_DIR/workspace/" 2>/dev/null || true

exec nanobot "$@"
