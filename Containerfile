FROM ubuntu:24.04

# Set to false to skip PowerShell 7 (it's the "optional" tool from the request)
ARG INSTALL_PWSH=true

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg lsb-release apt-transport-https \
        git zsh unzip jq less vim sudo locales openssh-client software-properties-common \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# --- Terraform + Packer (HashiCorp apt repo) ---
RUN wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list \
    && sudo apt update && sudo apt install terraform packer

# --- Azure CLI (Microsoft's official install script) ---
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# --- PowerShell 7 (optional) ---
RUN if [ "$INSTALL_PWSH" = "true" ]; then \
        wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
        && dpkg -i packages-microsoft-prod.deb \
        && rm packages-microsoft-prod.deb \
        && apt-get update && apt-get install -y --no-install-recommends powershell; \
    fi

# --- Powerlevel10k, installed system-wide ---
# Deliberately outside $HOME: distrobox bind-mounts the host's home directory over
# the container's, so anything baked into /home/<user> in the image would never be
# seen. Theme files live here; the actual ~/.zshrc is written by the bootstrap
# script below, directly into the shared home.
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/powerlevel10k
