#!/usr/bin/env bash
# Claude Code via the official native installer (installs to ~/.local/bin, auto-updates).
set -euo pipefail
command -v claude >/dev/null && { echo "claude already installed"; exit 0; }
curl -fsSL https://claude.ai/install.sh | bash
