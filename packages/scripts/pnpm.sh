#!/usr/bin/env bash
# pnpm via the official standalone installer (no sudo, no global npm).
set -euo pipefail
command -v pnpm >/dev/null && { echo "pnpm already installed"; exit 0; }
curl -fsSL https://get.pnpm.io/install.sh | sh -
