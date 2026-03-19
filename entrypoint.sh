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
  --arg model "${AI_MODEL:-anthropic/claude-opus-4-6}" \
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
