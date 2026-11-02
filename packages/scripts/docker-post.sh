#!/usr/bin/env bash
# Start Docker on boot and let the current user run it without sudo.
set -euo pipefail
sudo systemctl enable --now docker.service
if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    echo "Added $USER to the docker group: log out and back in for it to apply."
fi
