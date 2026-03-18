FROM python:3.12-slim

# System deps: git, Node.js 20, GitHub CLI, jq
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git gnupg jq procps && \
    # Node.js 20 (required for MCP servers via npx)
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    # GitHub CLI
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y --no-install-recommends gh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# NanoBot (pinned version — update deliberately after testing)
ARG NANOBOT_VERSION=0.1.4.post5
RUN pip install --no-cache-dir nanobot-ai==${NANOBOT_VERSION}

# Playwright + Chromium (headless browser for screenshots/scraping)
ARG PLAYWRIGHT_VERSION=1.58.0
RUN pip install --no-cache-dir playwright==${PLAYWRIGHT_VERSION} && \
    playwright install chromium --with-deps

# MCP filesystem server (installed globally so no npx download at runtime)
ARG MCP_FS_VERSION=2026.1.14
RUN npm install -g @modelcontextprotocol/server-filesystem@${MCP_FS_VERSION}

# Chromium needs --no-sandbox in containers (the container IS the sandbox)
ENV PLAYWRIGHT_CHROMIUM_SANDBOX=false

# Workspace defaults (copied into mount at startup by entrypoint)
COPY workspace/ /opt/nanobot/defaults/workspace/

# Entrypoint generates config.json from env vars and copies workspace defaults
COPY entrypoint.sh /opt/nanobot/entrypoint.sh
RUN chmod +x /opt/nanobot/entrypoint.sh

VOLUME ["/root/.nanobot"]
EXPOSE 18790

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD pgrep -f "nanobot" > /dev/null || exit 1

ENTRYPOINT ["/opt/nanobot/entrypoint.sh"]
CMD ["gateway"]
