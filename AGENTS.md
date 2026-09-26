## Overview

Personal cross-platform dotfiles for Windows (native + Windows Terminal), Linux (WSL2 + GNOME), and macOS (iTerm2 + zsh). There is no build, test, or lint step — the "product" is the set of config files plus platform installers that copy them into place.

## Git Workflow

Commit and push changes directly to `master` for this dotfiles repository. Do not create a branch or pull request unless explicitly asked.

## Installing

- Windows (PowerShell): `./init-windows.ps1`
- Linux / WSL: `./init-linux.sh`
- macOS: `./init-macos.sh`

The scripts **copy** (not symlink) files listed in `links` to their targets, removing existing targets first. System files, LaunchAgents, imported preferences, and merged configuration have separate installation steps. After editing a dotfile here, re-run the relevant installer to propagate the change. Add ordinary copied dotfiles to the applicable installer's `links` collection; Linux system files belong in `system_files`, and other resources need their corresponding installation step.

All installers install native `yq` if needed and invoke `.codex/configure.ps1` or `.codex/configure.sh` to merge `.codex/managed-config.toml` and `.codex/permissions.toml` into `$HOME/.codex/config.toml`. The merge preserves unrelated machine-specific settings, replaces managed values, removes the legacy `sandbox_workspace_write` table, and rebuilds `permissions.workspace_gitignore` with the target machine's Git ignore path. The full machine-specific config is not stored in this repository.

## Architecture

### Platform split via per-OS includes
`.gitconfig` is the shared base and is installed on every platform. It conditionally pulls in a platform-specific file using `includeIf`:
- `gitdir/i:C:/` → `.gitconfig-windows` (points SSH/signing at the Windows OpenSSH binaries and configures GitHub credentials)
- `gitdir:/Users/` → `.gitconfig-macos` (uses `gh` for GitHub credentials)

The shared config sets `core.safecrlf=warn` to warn about irreversible line-ending conversions. It does not set `core.autocrlf` or `core.eol`, so those settings can come from other Git configuration scopes or Git defaults. When changing Git behavior, decide whether it is shared (`.gitconfig`) or platform-specific. Windows and macOS installers copy their platform variants; Linux only needs the shared file.

### Line endings are load-bearing
`.gitattributes` uses `* text=auto eol=lf` to normalize detected text files to LF in Git and check them out with LF on every platform. `*.bat` and `*.cmd` are normalized to LF in Git but checked out with CRLF. The iTerm2 preferences plist is marked `-text` to prevent conversion. These attributes control this repository's line endings independently of `core.autocrlf`.

### What each installer manages
- All installers: Git, GitHub CLI, the `github/gh-stack` CLI extension, `yq`, and `mise` installation as needed, shared Git config and global ignores, shared agent instructions, platform-specific Claude settings/status line, Claude keybindings, Codex rules and merged configuration, Grok and OpenCode configuration, and SSH public key authorization.
- `init-windows.ps1`: Windows Git config, WSL config, Hack Nerd Font installation, mise shims in the user PATH, the all-users PowerShell profile and performance helper, Windows Terminal settings, and `/etc/wsl.conf` inside the default WSL distribution when available.
- `init-linux.sh`: bash, tmux installation and configuration, mise shims and `$HOME/.local/bin` in login profile PATH setup, `/etc/wsl.conf`, and Ptyxis settings when `dconf` is available.
- `init-macos.sh`: zsh configuration and login profile, macOS Git config, tmux installation and configuration, LinearMouse, the keyboard LaunchAgent, and iTerm2 preferences.

The repo root `AGENTS.md` provides project guidance and is **not** installed. Maintain shared cross-project instructions in `shared/AGENTS.md`; all platform installers copy it to `$HOME/.codex/AGENTS.md`, `$HOME/.grok/AGENTS.md`, and `$HOME/.claude/CLAUDE.md`.

### SSH public key naming
Name public keys in `ssh-keys/` using `user-hostname-keytype.pub`.

All platform installers dynamically authorize every `ssh-keys/*.pub` file, preserving existing authorized keys and skipping entries already present. Linux and macOS use `$HOME/.ssh/authorized_keys`. Windows uses `$HOME/.ssh/authorized_keys` for standard users and `$env:ProgramData/ssh/administrators_authorized_keys` for members of Administrators, following the default OpenSSH configuration. Windows administrator authorization requires an elevated PowerShell session. Adding public keys does not require changing the installers; removing a public key from the repository does not revoke previously installed access.

### WSL2 networking
`.wslconfig` (Windows-side, lives in `$HOME`) sets `networkingMode=mirrored`. `wsl.conf` (Linux-side, `/etc/wsl.conf`) enables systemd and sets `appendWindowsPath=false` so the Windows PATH isn't inherited. `.bashrc` additionally strips any leftover `/mnt/`-prefixed PATH entries and re-adds only the VS Code bin path, so that `code .` works from WSL without importing the whole Windows PATH. These three pieces work together — changing one (e.g. re-enabling Windows PATH interop) may require adjusting the others.

### .bashrc responsibilities beyond aliases
Manages an ssh-agent lifecycle (persists agent env to `~/.ssh/agent-environment`, auto-adds `~/.ssh/id_ed25519`), activates `mise`, `gh` completion, and prepends `opencode`/`amp` CLI paths. The `cj` alias runs Claude in a firejail sandbox with `--dangerously-skip-permissions`.
