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
   cd /mnt/c/Users/jeffs/Desktop/toolbox-docker
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

## Notes

- `~/.azure`, `~/.ssh`, and `~/.zshrc` all live under `$HOME`, which distrobox
  shares with the host - they persist across container recreation and image
  updates without any extra config.
- `scripts/01-create-devbox.sh` is safe to re-run; it skips container creation
  if `devbox` already exists and never overwrites an existing `~/.zshrc`. To
  rebuild from scratch: `distrobox rm devbox` then re-run the script.
- To skip PowerShell 7, rebuild the image with `--build-arg INSTALL_PWSH=false`
  (only relevant if you're building locally for testing; the published image
  from CI includes it).
