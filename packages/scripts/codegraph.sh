#!/usr/bin/env bash
# CodeGraph (code knowledge graph + MCP server) via its official installer, then register the
# MCP server for Claude Code at user scope. The owner's global CLAUDE.md relies on it.
set -euo pipefail
if ! command -v codegraph >/dev/null; then
    curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi
if command -v claude >/dev/null && ! claude mcp get codegraph >/dev/null 2>&1; then
    claude mcp add --scope user codegraph -- codegraph serve --mcp || echo "Add it later: claude mcp add --scope user codegraph -- codegraph serve --mcp"
fi
