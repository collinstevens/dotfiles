#!/bin/bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
    echo "Skipped Claude MCP servers: claude is not installed"
    exit 0
fi

claude mcp remove --scope user excalidraw >/dev/null 2>&1 || true
claude mcp add --scope user --transport http excalidraw https://mcp.excalidraw.com/mcp
