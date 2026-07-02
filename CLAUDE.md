# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal cross-platform dotfiles for a developer who works on both Windows (native + Windows Terminal) and Linux (WSL2 + GNOME). There is no build, test, or lint step — the "product" is the set of config files plus two installer scripts that copy them into place.

## Installing

- Windows (PowerShell): `./init.ps1`
- Linux / WSL: `./init.sh`

Both scripts **copy** (not symlink) each source file to its target in `$HOME` or a system path, removing any existing target first. After editing a dotfile here, re-run the relevant installer to propagate the change. Adding a new dotfile requires adding an entry to the `$links` array (`init.ps1`) or `links`/`system_files` arrays (`init.sh`) — the scripts do not auto-discover files.

## Architecture

### Platform split via per-OS includes
`.gitconfig` is the shared base and is installed on every platform. It conditionally pulls in a platform-specific file using `includeIf`:
- `gitdir/i:C:/` → `.gitconfig-windows` (sets `autocrlf=true`, points SSH/signing at the Windows OpenSSH binaries)
- `gitdir:/home/` → `.gitconfig-linux` (`autocrlf=false`)

When changing Git behavior, decide whether it is shared (`.gitconfig`) or platform-specific (the `-windows`/`-linux` variant). `init.ps1` installs `.gitconfig` + `.gitconfig-windows`; `init.sh` installs `.gitconfig` + `.gitconfig-linux`.

### Line endings are load-bearing
`.gitattributes` pins specific files: shell/config files are `eol=lf`, `*.ps1` is `eol=crlf`. Because Windows uses `autocrlf=true`, preserving these declarations matters — a PowerShell script with LF or a `.bashrc` with CRLF will break at runtime. Don't "normalize" line endings without checking `.gitattributes`.

### What each installer manages
- `init.ps1` (Windows): `.gitconfig`, `.gitconfig-windows`, `.wslconfig`, `.claude/settings.json`, `.claude/CLAUDE.md`, `.claude/keybindings.json`, the PowerShell profile (`powershell/Microsoft.PowerShell_profile.ps1` → `$HOME\Documents\PowerShell\`), and Windows Terminal `settings.json`. It resolves the Windows Terminal settings path from the installed Appx package, falling back to the unpackaged location.
- `init.sh` (Linux): `.bashrc`, `.gitconfig`, `.gitconfig-linux`, `.claude/settings.json`, `.claude/CLAUDE.md`, `.claude/keybindings.json` into `$HOME`; `wsl.conf` into `/etc/wsl.conf` (via `sudo install` when the target dir isn't writable); and loads `gnome-terminal.conf` into dconf when `dconf` is available.

Note: the repo root `CLAUDE.md` (this file) is project guidance for the dotfiles repo and is **not** installed. The installed `.claude/CLAUDE.md` is the user-level global memory (cross-project git guidelines) that lands at `$HOME/.claude/CLAUDE.md`.

### WSL2 networking
`.wslconfig` (Windows-side, lives in `$HOME`) sets `networkingMode=mirrored`. `wsl.conf` (Linux-side, `/etc/wsl.conf`) enables systemd and sets `appendWindowsPath=false` so the Windows PATH isn't inherited. `.bashrc` additionally strips any leftover `/mnt/`-prefixed PATH entries and re-adds only the VS Code bin path, so that `code .` works from WSL without importing the whole Windows PATH. These three pieces work together — changing one (e.g. re-enabling Windows PATH interop) may require adjusting the others.

### .bashrc responsibilities beyond aliases
Manages an ssh-agent lifecycle (persists agent env to `~/.ssh/agent-environment`, auto-adds `~/.ssh/id_ed25519`), activates `mise`, `gh` completion, and prepends `opencode`/`amp` CLI paths. The `cj` alias runs Claude in a firejail sandbox with `--dangerously-skip-permissions`.
