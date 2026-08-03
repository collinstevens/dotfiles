# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal cross-platform dotfiles for Windows (native + Windows Terminal), Linux (WSL2 + GNOME), and macOS (iTerm2 + zsh). There is no build, test, or lint step — the "product" is the set of config files plus platform installers that copy them into place.

## Installing

- Windows (PowerShell): `./init-windows.ps1`
- Linux / WSL: `./init-linux.sh`
- macOS: `./init-macos.sh`

The scripts **copy** (not symlink) each source file to its target in `$HOME` or a system path, removing any existing target first. They also use Mise-managed `yq` to merge `.codex/permissions.toml` into `$HOME/.codex/config.toml` without storing or replacing the full machine-specific config. After editing a dotfile here, re-run the relevant installer to propagate the change. Adding a new dotfile requires adding it to the applicable installer's `links` collection because the scripts do not auto-discover files.

## Architecture

### Platform split via per-OS includes
`.gitconfig` is the shared base and is installed on every platform. It conditionally pulls in a platform-specific file using `includeIf`:
- `gitdir/i:C:/` → `.gitconfig-windows` (points SSH/signing at the Windows OpenSSH binaries and configures GitHub credentials)
- `gitdir:/Users/` → `.gitconfig-macos` (uses `gh` for GitHub credentials)

The shared config disables automatic CRLF conversion, uses LF for normalized text, and warns about irreversible conversions. When changing Git behavior, decide whether it is shared (`.gitconfig`) or platform-specific. Windows and macOS installers copy their platform variants; Linux only needs the shared file.

### Line endings are load-bearing
`.gitattributes` stores text files with LF on every platform, with CRLF reserved for `*.bat` and `*.cmd`. The shared Git config also disables automatic CRLF conversion, preventing shell and shared config files from acquiring platform-dependent endings.

### What each installer manages
- `init-windows.ps1`: shared and Windows Git config, global ignores, WSL config, Windows Claude settings/status line, shared agent/config files, the all-users PowerShell profile, Windows Terminal settings, and `/etc/wsl.conf` inside WSL.
- `init-linux.sh`: bash, shared Git config, global ignores, Unix Claude settings/status line, shared agent/config files, `/etc/wsl.conf`, and GNOME Terminal settings.
- `init-macos.sh`: zsh, shared and macOS Git config, global ignores, Unix Claude settings/status line, shared agent/config files, LinearMouse, the keyboard LaunchAgent, and iTerm2 preferences.

Note: the repo root `CLAUDE.md` (this file) is project guidance for the dotfiles repo and is **not** installed. The installed `.claude/CLAUDE.md` is the user-level global memory (cross-project git guidelines) that lands at `$HOME/.claude/CLAUDE.md`.

### WSL2 networking
`.wslconfig` (Windows-side, lives in `$HOME`) sets `networkingMode=mirrored`. `wsl.conf` (Linux-side, `/etc/wsl.conf`) enables systemd and sets `appendWindowsPath=false` so the Windows PATH isn't inherited. `.bashrc` additionally strips any leftover `/mnt/`-prefixed PATH entries and re-adds only the VS Code bin path, so that `code .` works from WSL without importing the whole Windows PATH. These three pieces work together — changing one (e.g. re-enabling Windows PATH interop) may require adjusting the others.

### .bashrc responsibilities beyond aliases
Manages an ssh-agent lifecycle (persists agent env to `~/.ssh/agent-environment`, auto-adds `~/.ssh/id_ed25519`), activates `mise`, `gh` completion, and prepends `opencode`/`amp` CLI paths. The `cj` alias runs Claude in a firejail sandbox with `--dangerously-skip-permissions`.
