#!/bin/bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
    echo "Skipped Claude MCP servers: claude is not installed"
    exit 0
fi

claude mcp remove --scope user excalidraw >/dev/null 2>&1 || true

if [ -z "${EXCALIDRAW_API_KEY:-}" ]; then
    echo "Skipped the excalidraw MCP server: EXCALIDRAW_API_KEY is not set"
    exit 0
fi

claude mcp add --scope user --transport http excalidraw https://api.excalidraw.com/api/v1/mcp --header "Authorization: Bearer $EXCALIDRAW_API_KEY"
