#!/usr/bin/env bash
# Run this once inside your WSL2 Linux distro (not inside a container) to make
# sure podman + distrobox are available before building the devops toolbox image.
set -euo pipefail

if command -v podman >/dev/null 2>&1; then
    echo "podman already installed: $(podman --version)"
else
    echo "==> Installing podman"
    sudo apt-get update
    sudo apt-get install -y podman uidmap slirp4netns
fi

if command -v distrobox >/dev/null 2>&1; then
    echo "distrobox already installed: $(distrobox --version)"
elif apt-cache show distrobox >/dev/null 2>&1; then
    echo "==> Installing distrobox via apt"
    sudo apt-get install -y distrobox
else
    echo "==> distrobox isn't packaged for this distro/release; falling back to the"
    echo "    upstream install script (this pipes a remote script into 'sudo sh' -"
    echo "    see https://github.com/89luca89/distrobox/blob/main/install if you'd"
    echo "    rather review it first)."
    curl -fsSL https://raw.githubusercontent.com/89luca89/distrobox/main/install | sudo sh
fi

echo
echo "Done. podman + distrobox are ready."
