#!/bin/sh
set -e

# Validate required environment variables
: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is required}"
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is required}"
: "${TELEGRAM_USER_IDS:?TELEGRAM_USER_IDS is required}"
: "${GH_TOKEN:?GH_TOKEN is required}"

MOUNT_DIR="/root/.nanobot"
DEFAULTS_DIR="/opt/nanobot/defaults"

mkdir -p "$MOUNT_DIR/workspace"

# Build JSON array from comma-separated user IDs
ALLOW_FROM=$(echo "$TELEGRAM_USER_IDS" | tr ',' '\n' | jq -R . | jq -s .)

# Generate config.json from environment variables (jq ensures valid JSON)
jq -n \
  --arg api_key "$ANTHROPIC_API_KEY" \
  --arg tg_token "$TELEGRAM_BOT_TOKEN" \
  --argjson tg_users "$ALLOW_FROM" \
  --arg workspace "$MOUNT_DIR/workspace" \
  '{
    providers: { anthropic: { apiKey: $api_key } },
    agents: {
      defaults: {
        model: "anthropic/claude-opus-4-6",
        maxTokens: 8192,
        temperature: 0.1,
        maxToolIterations: 50,
        memoryWindow: 50
      }
    },
    tools: {
      exec: { timeout: 300 },
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
        allowFrom: $tg_users
      }
    },
    gateway: { host: "0.0.0.0", port: 18790 }
  }' > "$MOUNT_DIR/config.json"

# Copy workspace defaults from image (auto-deploys config updates on restart)
cp -r "$DEFAULTS_DIR/workspace/"* "$MOUNT_DIR/workspace/" 2>/dev/null || true

# Health endpoint for Azure Container Apps probes (nanobot doesn't bind a port)
python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'ok')
    def log_message(self, *a): pass
HTTPServer(('0.0.0.0', 18790), H).serve_forever()
" &

exec nanobot "$@"
