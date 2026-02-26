#!/bin/sh
set -e

MOUNT_DIR="/root/.nanobot"
DEFAULTS_DIR="/opt/nanobot/defaults"

# Generate config.json from environment variables
cat > "$MOUNT_DIR/config.json" <<EOF
{
  "providers": {
    "anthropic": {
      "apiKey": "${ANTHROPIC_API_KEY}"
    }
  },
  "agents": {
    "defaults": {
      "model": "anthropic/claude-sonnet-4-5",
      "maxTokens": 8192,
      "temperature": 0.1,
      "maxToolIterations": 40,
      "memoryWindow": 100
    }
  },
  "tools": {
    "restrictToWorkspace": true,
    "mcpServers": {
      "filesystem": {
        "command": "mcp-server-filesystem",
        "args": ["${MOUNT_DIR}/workspace"]
      }
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "${TELEGRAM_BOT_TOKEN}",
      "allowFrom": ["${TELEGRAM_USER_ID}"]
    }
  },
  "gateway": {
    "host": "0.0.0.0",
    "port": 18790
  }
}
EOF

# Copy workspace defaults from image (auto-deploys SOUL.md updates)
mkdir -p "$MOUNT_DIR/workspace"
cp -r "$DEFAULTS_DIR/workspace/"* "$MOUNT_DIR/workspace/" 2>/dev/null || true

exec nanobot "$@"
