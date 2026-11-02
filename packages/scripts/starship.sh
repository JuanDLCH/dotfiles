#!/usr/bin/env bash
# Starship prompt for distros without a package.
set -euo pipefail
command -v starship >/dev/null && { echo "starship already installed"; exit 0; }
mkdir -p "$HOME/.local/bin"
curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
