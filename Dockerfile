FROM python:3.12-slim

# System deps: git, Node.js 20, GitHub CLI
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git gnupg && \
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
ARG NANOBOT_VERSION=0.1.4.post2
RUN pip install --no-cache-dir nanobot-ai==${NANOBOT_VERSION}

# Playwright + Chromium (headless browser for screenshots/scraping)
RUN pip install --no-cache-dir playwright && \
    playwright install chromium --with-deps

# MCP filesystem server (installed globally so no npx download at runtime)
RUN npm install -g @modelcontextprotocol/server-filesystem

# Chromium needs --no-sandbox in containers (the container IS the sandbox)
ENV PLAYWRIGHT_CHROMIUM_SANDBOX=false

# Default workspace files (overridden when Azure file share is mounted)
COPY workspace/ /root/.nanobot/workspace/

VOLUME ["/root/.nanobot"]
EXPOSE 18790

ENTRYPOINT ["nanobot"]
CMD ["gateway"]
