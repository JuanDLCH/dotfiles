#!/usr/bin/env bash
# Visual Studio Code from Microsoft's repository (Debian/Ubuntu and Fedora).
set -euo pipefail
command -v code >/dev/null && { echo "code already installed"; exit 0; }
y=(); [[ ${YES:-0} == 1 ]] && y=(-y)
case ${FAMILY:-} in
    debian)
        sudo install -d -m 0755 /etc/apt/keyrings
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor |
            sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |
            sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
        sudo apt-get update
        sudo apt-get install "${y[@]}" code ;;
    fedora)
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        printf '%s\n' '[code]' 'name=Visual Studio Code' 'baseurl=https://packages.microsoft.com/yumrepos/vscode' \
            'enabled=1' 'gpgcheck=1' 'gpgkey=https://packages.microsoft.com/keys/microsoft.asc' |
            sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
        sudo dnf install "${y[@]}" code ;;
    *) echo "vscode.sh: unsupported family '${FAMILY:-}'" >&2; exit 1 ;;
esac
