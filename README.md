# dotfiles

Cross-platform dotfiles for Windows, Linux, and macOS.

## Install

Each command works on a fresh machine and on one that is already set up. It installs the prerequisites, creates `~/.ssh/id_ed25519` if it does not exist, clones this repository into `~/projects/collinstevens/dotfiles`, and runs the platform installer. Set `DOTFILES_DIR` to clone somewhere else.

Windows, from an elevated PowerShell (Terminal (Admin)):

```powershell
irm https://raw.githubusercontent.com/collinstevens/dotfiles/master/init-windows.ps1 | iex
```

Linux and WSL:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/collinstevens/dotfiles/master/init-linux.sh)"
```

macOS:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/collinstevens/dotfiles/master/init-macos.sh)"
```

On Linux without curl, replace `curl -fsSL` with `wget -qO-`.
