#!/usr/bin/env bash
# Enable the Bluetooth service.
set -euo pipefail
sudo systemctl enable --now bluetooth.service
