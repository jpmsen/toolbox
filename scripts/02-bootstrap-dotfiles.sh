#!/usr/bin/env bash
# Runs *inside* the distrobox container on first entry. Writes dotfiles into the
# shared $HOME and sets zsh as this box's default shell. Idempotent: never
# overwrites a ~/.zshrc you've already started customizing.
set -euo pipefail

if [ ! -f "${HOME}/.zshrc" ]; then
    cat > "${HOME}/.zshrc" <<'EOF'
# --- devops-toolbox default zshrc ---
source /opt/powerlevel10k/powerlevel10k.zsh-theme
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

autoload -Uz compinit && compinit
[ -f /etc/bash_completion.d/azure-cli ] && source /etc/bash_completion.d/azure-cli

# Picked up from the WSL host's ssh-agent bridge (scripts/03-setup-ssh-agent-bridge.sh),
# if it's been set up - ~/.ssh is shared with the host so the socket just works here too.
[ -S "$HOME/.ssh/agent.sock" ] && export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"

alias tf=terraform
EOF
    echo "==> Wrote ~/.zshrc"
else
    echo "==> ~/.zshrc already exists, leaving it untouched"
fi

echo "==> Setting zsh as the default shell for this box"
sudo chsh -s "$(command -v zsh)" "$(whoami)"

echo
echo "Note: install a Nerd Font (e.g. MesloLGS NF) in Windows Terminal for the"
echo "prompt icons to render correctly - see windows/install-meslo-nerd-font.ps1."
