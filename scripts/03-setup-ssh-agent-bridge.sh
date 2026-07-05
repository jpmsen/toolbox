#!/usr/bin/env bash
# Run this once inside your WSL2 Linux distro (not inside a container) to bridge
# a Windows-side SSH agent (e.g. Bitwarden desktop's "SSH Agent" feature) into
# WSL via npiperelay + socat. ~/.ssh is shared with every distrobox box, so once
# this is running, `ssh-add -l` works both in WSL and inside `devbox`.
set -euo pipefail

SOCK_PATH="${SSH_AUTH_SOCK_BRIDGE:-$HOME/.ssh/agent.sock}"
PIPE_NAME="${WINDOWS_SSH_PIPE:-//./pipe/openssh-ssh-agent}"
RELAY_SCRIPT="$HOME/.local/share/toolbox-bootstrap/ssh-agent-relay.sh"
RC_FILE="$HOME/.bashrc"
MARKER="# --- toolbox-docker ssh-agent bridge ---"

if command -v socat >/dev/null 2>&1; then
    echo "socat already installed: $(socat -V | head -n1)"
else
    echo "==> Installing socat"
    sudo apt-get update
    sudo apt-get install -y socat
fi

if command -v npiperelay.exe >/dev/null 2>&1; then
    NPIPERELAY="$(command -v npiperelay.exe)"
    echo "npiperelay.exe found on PATH: $NPIPERELAY"
else
    # winget's portable-package installs don't always register a PATH shim
    # (jstarks.npiperelay is one of these), so fall back to searching the
    # usual winget/scoop install locations under /mnt/c before giving up.
    NPIPERELAY="$(find /mnt/c/Users/*/AppData/Local/Microsoft/WinGet/Packages /mnt/c/Users/*/scoop/apps/npiperelay -iname 'npiperelay.exe' 2>/dev/null | head -n1 || true)"
    if [ -z "$NPIPERELAY" ]; then
        echo "ERROR: npiperelay.exe not found on PATH or in common install locations." >&2
        echo "        Install it on the Windows side first:" >&2
        echo "    winget install jstarks.npiperelay" >&2
        echo "(then re-run this script - no need to touch PATH, it'll search for it)" >&2
        exit 1
    fi
    echo "npiperelay.exe not on PATH, but found it at: $NPIPERELAY"
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

mkdir -p "$(dirname "$RELAY_SCRIPT")"
cat > "$RELAY_SCRIPT" <<EOF
#!/usr/bin/env bash
# Ensures a socat relay is listening on \$SOCK_PATH and forwarding to the Windows
# SSH agent pipe. Safe to source repeatedly - a stale/half-dead relay's socket
# file is removed and replaced.
SOCK_PATH="$SOCK_PATH"
PIPE_NAME="$PIPE_NAME"
NPIPERELAY="$NPIPERELAY"

mkdir -p "\$(dirname "\$SOCK_PATH")"
if ! ss -x 2>/dev/null | grep -q "\$SOCK_PATH"; then
    rm -f "\$SOCK_PATH"
    (setsid socat UNIX-LISTEN:"\$SOCK_PATH",fork EXEC:"\$NPIPERELAY -ei -s \$PIPE_NAME",nofork &) >/tmp/npiperelay.log 2>&1
fi
export SSH_AUTH_SOCK="\$SOCK_PATH"
EOF
chmod +x "$RELAY_SCRIPT"
echo "==> Wrote relay helper to $RELAY_SCRIPT"

if grep -qF "$MARKER" "$RC_FILE" 2>/dev/null; then
    echo "==> $RC_FILE already sources the ssh-agent bridge, leaving it untouched"
else
    {
        echo ""
        echo "$MARKER"
        echo "[ -f \"$RELAY_SCRIPT\" ] && source \"$RELAY_SCRIPT\""
    } >> "$RC_FILE"
    echo "==> Added bridge sourcing to $RC_FILE"
fi

echo
echo "Done. Open a new WSL shell (or 'source ~/.bashrc') and check 'ssh-add -l'."
echo "Note: the Windows-side agent (e.g. Bitwarden's SSH Agent, Settings > SSH Agent)"
echo "must be enabled, and the Windows 'OpenSSH Authentication Agent' service must be"
echo "stopped/disabled first, since both want the same named pipe."
