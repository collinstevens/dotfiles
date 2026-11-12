# dotfiles

Cross-platform dotfiles for Windows, Linux, and macOS.

## Fresh machine

Windows, from an elevated PowerShell (Terminal (Admin)):

```powershell
irm https://raw.githubusercontent.com/collinstevens/dotfiles/master/bootstrap.ps1 | iex
```

Linux, WSL, and macOS:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/collinstevens/dotfiles/master/bootstrap.sh)"
```

Without curl:

```sh
bash -c "$(wget -qO- https://raw.githubusercontent.com/collinstevens/dotfiles/master/bootstrap.sh)"
```

The bootstrap installs Git and the other prerequisites, creates `~/.ssh/id_ed25519` if it does not exist, clones this repository into `~/projects/collinstevens/dotfiles`, and runs the platform installer. Set `DOTFILES_DIR` to clone somewhere else.

## Existing checkout

- Windows, from an elevated PowerShell 7: `./init-windows.ps1`
- Linux and WSL: `./init-linux.sh`
- macOS: `./init-macos.sh`
