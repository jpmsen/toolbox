#!/usr/bin/env bash
# Run this once inside the distrobox container (after scripts/03-setup-ssh-agent-bridge.sh
# has been set up on the WSL host) to configure git to sign commits with your
# Bitwarden-held SSH key, per https://bitwarden.com/help/ssh-agent/#ssh-agent-forwarding
set -euo pipefail

if [ -z "${SSH_AUTH_SOCK:-}" ] || [ ! -S "${SSH_AUTH_SOCK}" ]; then
    echo "ERROR: SSH_AUTH_SOCK isn't set to a live socket." >&2
    echo "        Run scripts/03-setup-ssh-agent-bridge.sh on the WSL host first," >&2
    echo "        then open a fresh shell (host and inside this box) and retry." >&2
    exit 1
fi

mapfile -t KEYS < <(ssh-add -L 2>/dev/null || true)
if [ "${#KEYS[@]}" -eq 0 ]; then
    echo "ERROR: no keys visible via 'ssh-add -L' - check that Bitwarden's SSH Agent" >&2
    echo "        is enabled and unlocked on the Windows side." >&2
    exit 1
fi

if [ "${#KEYS[@]}" -eq 1 ]; then
    SIGNING_KEY="${KEYS[0]}"
    echo "==> Using the only key the agent offers: ${SIGNING_KEY#* }"
else
    echo "Multiple keys are available from the agent - pick one to sign with:"
    select KEY in "${KEYS[@]}"; do
        if [ -n "${KEY:-}" ]; then
            SIGNING_KEY="$KEY"
            break
        fi
        echo "Invalid choice, try again."
    done
fi

GIT_NAME="$(git config --global user.name || true)"
if [ -z "$GIT_NAME" ]; then
    read -rp "git user.name isn't set yet - enter your name for commits: " GIT_NAME
    git config --global user.name "$GIT_NAME"
fi

GIT_EMAIL="$(git config --global user.email || true)"
if [ -z "$GIT_EMAIL" ]; then
    read -rp "git user.email isn't set yet - enter the email to sign commits as: " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
fi

ALLOWED_SIGNERS="$HOME/.ssh/allowed_signers"
touch "$ALLOWED_SIGNERS"
SIGNER_LINE="${GIT_EMAIL} ${SIGNING_KEY}"
if grep -qF "$SIGNER_LINE" "$ALLOWED_SIGNERS" 2>/dev/null; then
    echo "==> ${ALLOWED_SIGNERS} already has this signer, leaving it untouched"
else
    echo "$SIGNER_LINE" >> "$ALLOWED_SIGNERS"
    echo "==> Added ${GIT_EMAIL}'s key to ${ALLOWED_SIGNERS}"
fi

git config --global gpg.format ssh
git config --global user.signingkey "$SIGNING_KEY"
git config --global commit.gpgsign true
git config --global gpg.ssh.allowedSignersFile "$ALLOWED_SIGNERS"

echo
echo "Done. Test with:"
echo "    git commit --allow-empty -m 'test signed commit' && git log --show-signature -1"
