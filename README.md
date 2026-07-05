# toolbox-docker

Devops onboarding toolbox: a distrobox/podman container (git, terraform, packer,
az cli, optionally PowerShell 7, zsh + powerlevel10k) running inside a WSL2
distro on an Intune-managed Windows machine.

The image is built by [.github/workflows/build-image.yml](.github/workflows/build-image.yml)
and published to `ghcr.io/jpmsen/toolbox`. Nobody builds it locally - the
scripts here only ever pull.

## A. Create the WSL2 distro (Windows host)

1. Check what you already have:
   ```
   wsl --status
   wsl -l -v
   ```
2. If you don't have a distro yet to host podman/distrobox, install one:
   ```
   wsl --install -d Ubuntu-24.04
   ```
   This is just the *host* distro - it doesn't need to match the Ubuntu
   version used inside the container image.
3. Launch it once (`wsl -d Ubuntu-24.04`) to finish first-run setup. You'll be
   prompted for a Unix username/password.
   - This account is local to the WSL2 virtual disk, not tied to
     Intune/AD - it isn't really a security boundary (anyone with your
     Windows session can `wsl -u root` regardless of this password), so
     optimize for something quick to type since you'll use it for every
     `sudo`, rather than for complexity.
   - Username doesn't need to match your Windows username; it only
     determines your `$HOME` path (`/home/<name>`).

## B. Get the image building on GitHub

4. Push to `main` to trigger the workflow:
   ```
   git add -A && git commit -m "..." && git push
   ```
5. Watch it build under the repo's **Actions** tab.
6. **First run only**: go to `github.com/jpmsen?tab=packages` -> `toolbox`
   package -> Package settings -> set visibility to **Public**. GHCR defaults
   new packages to private regardless of the repo's visibility, so this is a
   one-time manual step - skip it and `podman pull` will 403.

## C. Inside WSL2: prereqs, pull, bootstrap

7. Open your WSL2 distro and go to the repo (it lives on the Windows side):
   ```
   cd /mnt/c/Users/......
   chmod +x scripts/*.sh
   ```
8. Install podman + distrobox:
   ```
   ./scripts/00-install-podman-distrobox.sh
   ```
9. Pull the image, create the container, bootstrap dotfiles:
   ```
   ./scripts/01-create-devbox.sh
   ```
   This pulls `ghcr.io/jpmsen/toolbox:latest`, creates a distrobox container
   named `devbox`, writes a starter `~/.zshrc` (only if one doesn't already
   exist - safe to re-run), and sets zsh as the box's default shell.
10. Enter it and set up the prompt once:
    ```
    distrobox enter devbox
    p10k configure
    ```

## D. Windows Terminal polish

11. Install the recommended Nerd Font from a normal **Windows** PowerShell
    window (not inside WSL):
    ```
    windows/install-meslo-nerd-font.ps1
    ```
12. Windows Terminal -> Settings -> the WSL2 distro's profile -> Appearance ->
    Font face -> `MesloLGS NF`.

Day to day, everything after this is just `distrobox enter devbox` from the
WSL2 shell.

## E. SSH agent forwarding from Bitwarden (optional)

If you use Bitwarden desktop's SSH Agent feature to hold your keys, bridge it
into WSL2 - `~/.ssh` is shared with every distrobox box, so this makes
`ssh-add -l` work both in WSL and inside `devbox`.

13. On Windows:
    - Bitwarden desktop -> Settings -> SSH Agent -> enable it. Make sure
      Bitwarden itself is **not** set to run elevated (shortcut/exe ->
      Properties -> Compatibility tab -> "Run this program as an
      administrator" should be unchecked, and check Properties -> Advanced...
      on the shortcut too) - an elevated Bitwarden's named pipe silently
      denies every non-elevated client, including a plain `ssh-add -l` and
      WSL, with a permission error that has nothing to do with the bridge
      itself. Fully quit Bitwarden from the tray and relaunch normally after
      changing this.
    - Disable the built-in Windows OpenSSH agent service - Bitwarden's agent
      takes over the same named pipe (`\\.\pipe\openssh-ssh-agent`), so the
      two will conflict if both are running:
      ```
      Set-Service ssh-agent -StartupType Disabled
      Stop-Service ssh-agent
      ```
    - Install `npiperelay`:
      ```
      winget install jstarks.npiperelay
      ```
      This is a portable package - winget doesn't add it to `PATH`, but
      `scripts/03-setup-ssh-agent-bridge.sh` searches the common winget/scoop
      install locations for it automatically, so no `PATH` edits are needed.
14. Back in WSL2:
    ```
    ./scripts/03-setup-ssh-agent-bridge.sh
    ```
    Installs `socat`, locates `npiperelay.exe`, writes a relay helper under
    `~/.local/share/toolbox-bootstrap/`, and wires it into `~/.bashrc`. Open a
    new WSL shell and confirm with `ssh-add -l`.
15. Inside `devbox` (or any box), `ssh-add -l` should show the same keys with
    no extra config - `02-bootstrap-dotfiles.sh`'s default `.zshrc` already
    exports `SSH_AUTH_SOCK` when the relay socket exists.
16. Sign commits with that key instead of GPG, per
    [Bitwarden's SSH agent commit signing guide](https://bitwarden.com/help/ssh-agent/#ssh-agent-forwarding).
    ```
    ./scripts/04-setup-git-ssh-signing.sh
    ```
    Picks a key from the agent (prompts if it offers more than one), sets
    `gpg.format ssh`, `user.signingkey`, `commit.gpgsign true`, and
    `gpg.ssh.allowedSignersFile` in your global `~/.gitconfig`, and records the
    key against your git email in `~/.ssh/allowed_signers` (created if
    missing).

## Notes

- `~/.azure`, `~/.ssh`, `~/.zshrc`, and `~/.gitconfig` all live under `$HOME`,
  which distrobox shares with the host - they persist across container
  recreation and image updates without any extra config.
- `scripts/01-create-devbox.sh` is safe to re-run; it skips container creation
  if `devbox` already exists and never overwrites an existing `~/.zshrc`. To
  rebuild from scratch: `distrobox rm devbox` then re-run the script.
- To skip PowerShell 7, rebuild the image with `--build-arg INSTALL_PWSH=false`
  (only relevant if you're building locally for testing; the published image
  from CI includes it).
- `scripts/03-setup-ssh-agent-bridge.sh` is optional and safe to re-run; it
  only touches `~/.bashrc` once (guarded by a marker comment) and never
  overwrites the relay helper's target path if you've customized it.
- `scripts/04-setup-git-ssh-signing.sh` is optional and safe to re-run; it
  only appends to `~/.ssh/allowed_signers` if the signer line isn't already
  there, and re-running `git config --global` with the same values is a
  no-op.
