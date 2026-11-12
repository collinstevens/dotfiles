## Overview

Personal cross-platform dotfiles for Windows (native + Windows Terminal), Linux (WSL2 + GNOME), and macOS (iTerm2 + zsh). There is no build, test, or lint step — the "product" is the set of config files plus platform installers that copy them into place.

## Machine-specific guidance

If `AGENTS.local.md` exists in the repo root, read it and follow it as machine-specific project guidance. It is excluded from Git through `.git/info/exclude` and is never committed.

## Git Workflow

Commit and push changes directly to `master` for this dotfiles repository. Do not create a branch or pull request unless explicitly asked.

## Installing

Each installer also bootstraps a fresh machine, so the README documents one command per platform that downloads and runs it:

- Windows (elevated Windows PowerShell or PowerShell): `irm https://raw.githubusercontent.com/collinstevens/dotfiles/master/init-windows.ps1 | iex`
- Linux / WSL: `bash -c "$(curl -fsSL https://raw.githubusercontent.com/collinstevens/dotfiles/master/init-linux.sh)"`
- macOS: `bash -c "$(curl -fsSL https://raw.githubusercontent.com/collinstevens/dotfiles/master/init-macos.sh)"`

From an existing checkout, run `./init-windows.ps1`, `./init-linux.sh`, or `./init-macos.sh`.

Every installer must stay idempotent: a rerun on a configured machine must succeed and leave it in the same state. Guard installs with a presence check, deduplicate appended lines, and replace copied files rather than appending to them.

Each installer starts with a bootstrap section. It installs Git and the other prerequisites and creates `$HOME/.ssh/id_ed25519` without a passphrase if it does not exist. The key's comment is `user-hostname` in lowercase, matching the `ssh-keys/` naming. The bootstrap does not add the key to `ssh-keys/`; the main install registers it with GitHub, adds GitHub's SSH host keys from `gh api meta` to `known_hosts`, and switches an `https://github.com/` `origin` to SSH. If the SSH remote cannot be reached, it restores the HTTPS URL and warns. When the installer is not running from a file, as with `iex` or `bash -c`, the bootstrap clones this repository over HTTPS into `$HOME/projects/collinstevens/dotfiles` and runs the checkout's copy of the installer. An existing checkout is fast-forwarded instead; if that fails, the installer warns and continues with the checkout as it is. `DOTFILES_DIR` overrides the checkout location, and `DOTFILES_REPOSITORY` overrides the clone URL. The Unix installers must be run through `bash -c "$(...)"` rather than piped into `bash`, so prompts read from the terminal instead of the script.

The bootstrap section of `init-windows.ps1` must stay compatible with Windows PowerShell 5.1 and with `Invoke-Expression`, which parses the whole file first. Keep it in script blocks that `throw` rather than `exit`, so a failure does not close the caller's window and no variables leak into the caller's session. It requires an elevated session, registers winget if needed, installs Git with winget, and installs the latest PowerShell LTS MSI from the PowerShell GitHub releases when `pwsh` is missing. Run from Windows PowerShell, it hands off to `pwsh`. Never install PowerShell with winget or the Microsoft Store. Those install the MSIX package, whose `$PSHOME` is read-only, so `init-windows.ps1` cannot install `$PROFILE.AllUsersAllHosts`. PowerShell 7.7 and later ship no MSI, so the MSI install stays on the 7.6 LTS line. The MSI opts into Microsoft Update for patch releases. `init-windows.ps1` adds a blocking winget pin on `Microsoft.PowerShell` so `winget upgrade --all` cannot replace the MSI with the MSIX.

`init-linux.sh` installs Git, curl, and `ssh-keygen` with the system package manager. `init-macos.sh` installs Homebrew if it is missing, then Git.

The scripts **copy** (not symlink) files listed in `links` to their targets, removing existing targets first. System files, LaunchAgents, imported preferences, and merged configuration have separate installation steps. After editing a dotfile here, re-run the relevant installer to propagate the change. Add ordinary copied dotfiles to the applicable installer's `links` collection; Linux system files belong in `system_files`, and other resources need their corresponding installation step.

The Windows and macOS installers install native `yq` if needed. The Linux installer uses the mise `yq` through `mise exec yq@latest`. All installers invoke `.codex/configure.ps1` or `.codex/configure.sh` to merge `.codex/managed-config.toml` and `.codex/permissions.toml` into `$HOME/.codex/config.toml`. The merge preserves unrelated machine-specific settings, replaces managed values, removes the legacy `sandbox_workspace_write` table, and rebuilds `permissions.workspace_gitignore` with the target machine's Git ignore path. The full machine-specific config is not stored in this repository.

## Architecture

### Platform split via per-OS includes
`.gitconfig` is the shared base and is installed on every platform. It conditionally pulls in a platform-specific file using `includeIf`:
- `gitdir/i:C:/` → `.gitconfig-windows` (points SSH/signing at the Windows OpenSSH binaries and configures GitHub credentials)
- `gitdir:/Users/` → `.gitconfig-macos` (uses `gh` for GitHub credentials)

The shared config sets `core.safecrlf=warn` to warn about irreversible line-ending conversions. It does not set `core.autocrlf` or `core.eol`, so those settings can come from other Git configuration scopes or Git defaults. When changing Git behavior, decide whether it is shared (`.gitconfig`) or platform-specific. Windows and macOS installers copy their platform variants; Linux only needs the shared file.

### Line endings are load-bearing
`.gitattributes` uses `* text=auto eol=lf` to normalize detected text files to LF in Git and check them out with LF on every platform. `*.bat` and `*.cmd` are normalized to LF in Git but checked out with CRLF. The iTerm2 preferences plist is marked `-text` to prevent conversion. These attributes control this repository's line endings independently of `core.autocrlf`.

### What each installer manages
- All installers: Git, GitHub CLI, the `github/gh-stack` CLI extension, a `gh` login with the `admin:public_key` and `admin:ssh_signing_key` scopes, registration of `$HOME/.ssh/id_ed25519.pub` as a GitHub authentication and signing key when either is missing, `yq`, and `mise` installation as needed, global mise tools, .NET diagnostic tools, shared Git config and global ignores, shared agent instructions, platform-specific Claude settings/status line, Claude keybindings, Claude Code through its native installer when `claude` is missing (it updates itself afterward), the Claude agent-summary preload, the user-scope Excalidraw+ MCP server for Claude (`.claude/configure-mcp.ps1` or `.claude/configure-mcp.sh`, authenticated with the `EXCALIDRAW_API_KEY` environment variable and skipped when `claude` is not installed or the variable is unset), Codex rules and merged configuration, Grok and OpenCode configuration, and SSH public key authorization.
- `init-windows.ps1`: PowerToys, a blocking winget pin on PowerShell, Windows Git config, WSL config, Hack Nerd Font installation, mise shims in the user PATH, the all-users PowerShell profile and performance helper, Windows Terminal installation when it is missing and its settings, and `/etc/wsl.conf` inside the default WSL distribution when available.
- `init-linux.sh`: bash, tmux installation and configuration, mise shims and `$HOME/.local/bin` in login profile PATH setup, `/etc/wsl.conf`, and Ptyxis settings when `dconf` is available.
- `init-macos.sh`: zsh configuration and login profile, macOS Git config, tmux installation and configuration, LinearMouse, the keyboard LaunchAgent, and iTerm2 preferences.

The repo root `AGENTS.md` provides project guidance and is **not** installed. Maintain shared cross-project instructions in `shared/AGENTS.md`; all platform installers copy it to `$HOME/.codex/AGENTS.md`, `$HOME/.grok/AGENTS.md`, and `$HOME/.claude/CLAUDE.md`.

### Global mise tools
Each platform installer lists the global tools in `miseTools` or `mise_tools`, runs `mise use --global` with `@latest` for each, and sets `auto_update = false` on each entry with `mise config set --global`. Keep the three lists identical. Automatic updates are disabled because the update check blocks the first shell of the day. The installers also unset `self_update.auto` for the same reason. Run `mise upgrade --global` to update the tools, and run `mise self-update` to update mise itself. Mise holds new releases for its default 24-hour `minimum_release_age`. Tools outside the list are left alone.

Install mise with its official script, never a package manager: `irm https://mise.run/powershell | iex` on Windows and `curl -fsSL https://mise.run | sh` on Linux and macOS. Both place it in `$HOME/.local/bin`.

### .NET installation
The .NET SDK is one of the global mise tools, and each platform installer installs the diagnostic tools inline through `mise exec dotnet@latest`. The SDK includes the .NET and ASP.NET Core runtimes. Rerunning an installer also updates the diagnostic tools to their newest releases.

Tools are installed with `dotnet tool install --global`; this also updates existing tools. Most tools use `--allow-roll-forward`. `dotnet-symbol` already enables major-version roll-forward with a legacy setting that conflicts with that flag. Shell PATH setup includes `$HOME/.dotnet/tools`, and mise activation supplies `DOTNET_ROOT`. macOS skips the unsupported `dotnet-debug` tool. Debugger registration through `dotnet-sos install` or `dotnet-debugger-extensions install` remains a separate step; these commands overwrite the same extension installation.

### Claude agent-summary preload
`.claude/no-agent-summary.js` is a Bun preload that stops Claude Code from sending each background agent's full transcript to the model every 30 seconds to refresh its 3–5 word status line. All installers copy it to `$HOME/.claude/no-agent-summary.js` and set `BUN_OPTIONS` to preload it: Windows as a User environment variable, Linux in `.bashrc`, and macOS in `.zprofile`. Restart Claude Code, including `claude daemon stop --any`, after the variable changes.

The hook recognizes the summary timer by the `[AgentSummary] Timer fired` string in its callback source. If a Claude Code update renames or moves that string, summaries silently return. To check, run an interactive session with `--debug-file`, keep a background subagent busy for two minutes, and confirm the log has no `[AgentSummary] Timer fired` lines.

### SSH public key naming
Name public keys in `ssh-keys/` using `user-hostname-keytype.pub`.

All platform installers dynamically authorize every `ssh-keys/*.pub` file, preserving existing authorized keys and skipping entries already present. Linux and macOS use `$HOME/.ssh/authorized_keys`. Windows uses `$HOME/.ssh/authorized_keys` for standard users and `$env:ProgramData/ssh/administrators_authorized_keys` for members of Administrators, following the default OpenSSH configuration. Windows administrator authorization requires an elevated PowerShell session. Adding public keys does not require changing the installers; removing a public key from the repository does not revoke previously installed access.

### WSL2 networking
`.wslconfig` (Windows-side, lives in `$HOME`) sets `networkingMode=mirrored`. `wsl.conf` (Linux-side, `/etc/wsl.conf`) enables systemd and sets `appendWindowsPath=false` so the Windows PATH isn't inherited. `.bashrc` additionally strips any leftover `/mnt/`-prefixed PATH entries and re-adds only the VS Code bin path, so that `code .` works from WSL without importing the whole Windows PATH. These three pieces work together — changing one (e.g. re-enabling Windows PATH interop) may require adjusting the others.

### .bashrc responsibilities beyond aliases
Manages an ssh-agent lifecycle (persists agent env to `~/.ssh/agent-environment`, auto-adds `~/.ssh/id_ed25519`), activates `mise`, `gh` completion, and prepends `opencode`/`amp` CLI paths. The `cj` alias runs Claude in a firejail sandbox with `--dangerously-skip-permissions`.
