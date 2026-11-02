#!/usr/bin/env bash
# Fresh install -> my setup. Installs git + chezmoi, then lets chezmoi ask for
# device/desktop/suites and apply everything.
#
#   From a clone:  ./bootstrap.sh
#   From nothing:  bash -c "$(curl -fsSL https://raw.githubusercontent.com/JuanDLCH/my-linux-configs/main/bootstrap.sh)"
#
# Extra args go to `chezmoi init` (e.g. --promptDefaults, --prompt).
set -euo pipefail

REPO=${MY_LINUX_REPO:-https://github.com/JuanDLCH/my-linux-configs.git}
here=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)

pm_install() {
    if command -v pacman >/dev/null; then sudo pacman -S --needed --noconfirm "$@"
    elif command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y "$@"
    elif command -v dnf >/dev/null; then sudo dnf install -y "$@"
    elif command -v zypper >/dev/null; then sudo zypper install -y "$@"
    else echo "No known package manager; install $* yourself." >&2; return 1
    fi
}

command -v git >/dev/null || pm_install git curl

if ! command -v chezmoi >/dev/null; then
    # Distro package where it exists, else the official static binary in ~/.local/bin.
    pm_install chezmoi 2>/dev/null || {
        mkdir -p "$HOME/.local/bin"
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    }
    export PATH="$HOME/.local/bin:$PATH"
fi

if [[ -n $here && -f $here/.chezmoiroot ]]; then
    exec chezmoi init --apply --source "$here" "$@"
else
    exec chezmoi init --apply "$@" "$REPO"
fi
