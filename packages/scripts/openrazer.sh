#!/usr/bin/env bash
# OpenRazer post-install: plugdev group, user daemon, kernel headers check.
set -euo pipefail
if getent group plugdev >/dev/null && ! id -nG "$USER" | grep -qw plugdev; then
    sudo gpasswd -a "$USER" plugdev
    echo "Added $USER to plugdev: log out and back in for it to apply."
fi
systemctl --user enable --now openrazer-daemon.service 2>/dev/null || true
# The driver is DKMS: it only builds when headers for the running kernel exist.
if [[ ! -d /usr/lib/modules/$(uname -r)/build ]]; then
    echo "WARNING: no kernel headers for $(uname -r) (Arch: linux-headers or linux-cachyos-headers;" \
        "Debian: linux-headers-\$(uname -r)). Install them, then reinstall the openrazer driver." >&2
fi
