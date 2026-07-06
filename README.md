# toolbox-docker

Devops onboarding toolbox: a distrobox/podman container (git, terraform, packer,
az cli, optionally PowerShell 7, zsh + powerlevel10k) running inside a WSL2
distro on an Intune-managed Windows machine.

The image is built by [.github/workflows/build-image.yml](.github/workflows/build-image.yml)
and published to `ghcr.io/jpmsen/toolbox`. Nobody builds it locally - the
scripts here only ever pull.

## A. Windows Terminal polish
1. Install a [Nerd Font](https://www.nerdfonts.com/font-downloads) into your machine. Not sure which one to pick? Choose [Meslo](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Meslo.zip)
2. Windows Terminal -> Settings -> the WSL2 distro's profile -> Appearance ->
    Font face -> `MesloLGS NF`.

## B. SSH agent forwarding from Bitwarden (optional)

If you use Bitwarden desktop's SSH Agent feature to hold your keys, bridge it
into WSL2 - `~/.ssh` is shared with every distrobox box, so this makes
`ssh-add -l` work both in WSL and inside `devbox`.

3. On Windows:
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
4. Create an SSH key inside Bitwarden. Normally, Bitwarden itself creates an SSH key with the `ssh-ed25519` algorithm. But Azure DevOps does not support this algoritm. So you need to generate this key on your Windows host first, and then import it to Bitwarden.
    - Add an RSA ssh key:
      ```
      ssh-keygen -t rsa -b 4096
      ```
    - You will be prompted a file location and password. Make sure to choose a strong password and remember this password (for example; in Bitwarden)
    - Go to to specified file location and open it. You will see a file starting with `-----BEGIN OPENSSH PRIVATE KEY-----`, copy this entire file
    - Open Bitwarden, press New -> SSH Key. In the private key section, press the upwards pointing array. You will be prompted a password; fill in the strong password you supplied before. Your key will then be succesfully imported. Inside the public key field, the text should start with `ssh-rsa`
    - Make sure to add a field to store your strong password
    - You can remove the SSH key on your local computer

## C. Create the WSL2 distro (Windows host)

5. Check what you already have:
   ```
   wsl --status
   wsl -l -v
   ```
6. If you don't have a distro yet to host podman/distrobox, install one:
   ```
   wsl --install -d Ubuntu-24.04
   ```
   This is just the *host* distro - it doesn't need to match the Ubuntu
   version used inside the container image.
7. Launch it once (`wsl -d Ubuntu-24.04`) to finish first-run setup. You'll be
   prompted for a Unix username/password.
   - This account is local to the WSL2 virtual disk, not tied to
     Intune/AD - it isn't really a security boundary (anyone with your
     Windows session can `wsl -u root` regardless of this password), so
     optimize for something quick to type since you'll use it for every
     `sudo`, rather than for complexity.
   - Username doesn't need to match your Windows username; it only
     determines your `$HOME` path (`/home/<name>`).

## C. Inside WSL2: prereqs, pull, bootstrap

8. Open your WSL2 distro and go to the repo (it lives on the Windows side):
   ```
   cd /mnt/c/Users/......
   chmod +x scripts/*.sh
   ```
9. Install podman + distrobox:
   ```
   ./scripts/00-install-podman-distrobox.sh
   ```
10. Pull the image, create the container, bootstrap dotfiles:
   ```
   ./scripts/01-create-devbox.sh
   ```
   This pulls `ghcr.io/jpmsen/toolbox:latest`, creates a distrobox container
   named `devbox`, writes a starter `~/.zshrc` (only if one doesn't already
   exist - safe to re-run), and sets zsh as the box's default shell.
   
11. You will be automatically entered into the distrobox. Complete the steps prompted on your screen and when finished, exit the `devbox`:
    ```
    exit devbox
    ```
    You can also enter the devbox by using the following command
    ```
    distrobox enter devbox
    ```
12. Back in WSL2:
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
    [Bitwarden's SSH agent commit signing guide](https://bitwarden.com/help/ssh-agent/#ssh-agent-forwarding). Back in WSL2:
    ```
    ./scripts/04-setup-git-ssh-signing.sh
    ```
    Picks a key from the agent (prompts if it offers more than one, so note
    which one you pick), sets `gpg.format ssh`, `user.signingkey`,
    `commit.gpgsign true`, and `gpg.ssh.allowedSignersFile` in your global
    `~/.gitconfig`, and records the key against your git email in
    `~/.ssh/allowed_signers` (created if missing).
17. Register that same public key with GitHub (or whichever remote host) - a
    key living in Bitwarden's agent is useless to a remote until the remote
    knows about it:
    - Get the exact public key text again with `ssh-add -L` if you need it
      (inside WSL or `devbox`) - it's whichever key you picked in step 16.
    - GitHub -> **Settings -> SSH and GPG keys -> New SSH key**, paste it in
      **twice**, once per "Key type":
      - **Authentication Key** - lets you `git push`/`pull` over SSH.
      - **Signing Key** - lets GitHub show your commits as "Verified". These
        are tracked separately even though it's the same key - adding it only
        as an Authentication Key is why a correctly-signed commit can still
        show up as "Unverified" on GitHub.
    - The commit author email (`git config user.email`, set in step 16) also
      has to match a **verified email** on your GitHub account, or GitHub
      still won't attribute the signature to you even with the key registered
      correctly.
    - Point each repo's remote at SSH instead of HTTPS, so `git push` uses the
      agent instead of prompting for a username/Personal Access Token:
      ```
      git remote set-url origin git@github.com:<owner>/<repo>.git
      ```
    - Already-pushed commits don't need to be re-signed or re-pushed once the
      key is registered - GitHub re-evaluates signatures against your current
      key list and will flip existing commits to "Verified" retroactively.

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
