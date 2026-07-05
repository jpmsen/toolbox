#!/usr/bin/env bash
# Pulls the devops-toolbox image from GHCR and creates/updates the distrobox
# container. The image itself is built by .github/workflows/build-image.yml -
# this script never builds locally, it only ever pulls.
# Safe to re-run: skips the container-create step if it already exists, and
# never overwrites dotfiles you've already customized.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE_NAME="${IMAGE_NAME:-ghcr.io/jpmsen/toolbox:latest}"
BOX_NAME="${BOX_NAME:-devbox}"

echo "==> Pulling ${IMAGE_NAME}"
podman pull "${IMAGE_NAME}"

if podman container exists "${BOX_NAME}"; then
    echo "==> Container '${BOX_NAME}' already exists, skipping create"
    echo "    (to rebuild from scratch: distrobox rm ${BOX_NAME} && re-run this script)"
else
    echo "==> Creating distrobox container '${BOX_NAME}'"
    distrobox create \
        --name "${BOX_NAME}" \
        --image "${IMAGE_NAME}" \
        --yes
fi

echo "==> Staging dotfile bootstrap into \$HOME (shared with every box)"
mkdir -p "${HOME}/.local/share/toolbox-bootstrap"
cp "${SCRIPT_DIR}/02-bootstrap-dotfiles.sh" "${HOME}/.local/share/toolbox-bootstrap/"
chmod +x "${HOME}/.local/share/toolbox-bootstrap/02-bootstrap-dotfiles.sh"

echo "==> Running dotfile bootstrap inside '${BOX_NAME}'"
distrobox enter "${BOX_NAME}" -- bash "${HOME}/.local/share/toolbox-bootstrap/02-bootstrap-dotfiles.sh"

echo
echo "Done. Enter your devbox any time with: distrobox enter ${BOX_NAME}"
echo "First time in zsh, run 'p10k configure' to set up your prompt."
