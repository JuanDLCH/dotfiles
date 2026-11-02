#!/usr/bin/env bash
# uv (Python) via the official installer.
set -euo pipefail
command -v uv >/dev/null && { echo "uv already installed"; exit 0; }
curl -LsSf https://astral.sh/uv/install.sh | sh
