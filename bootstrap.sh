#!/bin/bash
set -euo pipefail

repository="${DOTFILES_REPOSITORY:-https://github.com/collinstevens/dotfiles.git}"
directory="${DOTFILES_DIR:-$HOME/projects/collinstevens/dotfiles}"

run_as_root() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

load_homebrew() {
    local brew_path
    for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$brew_path" ]; then
            eval "$("$brew_path" shellenv)"
            return 0
        fi
    done
    return 1
}

install_git_linux() {
    if command -v apt-get >/dev/null 2>&1; then
        run_as_root apt-get update
        run_as_root apt-get install -y ca-certificates curl git
    elif command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y curl git
    elif command -v pacman >/dev/null 2>&1; then
        run_as_root pacman -S --needed --noconfirm curl git
    elif command -v zypper >/dev/null 2>&1; then
        run_as_root zypper --non-interactive install curl git
    elif command -v apk >/dev/null 2>&1; then
        run_as_root apk add bash curl git
    else
        echo "Error: no supported package manager found; install git and curl and rerun the bootstrap" >&2
        exit 1
    fi
}

case "$(uname -s)" in
    Darwin)
        init_script="init-macos.sh"
        if ! command -v brew >/dev/null 2>&1 && ! load_homebrew; then
            sudo -v
            NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            if ! load_homebrew; then
                echo "Error: Homebrew was installed but brew is not available" >&2
                exit 1
            fi
        fi
        if ! brew list git >/dev/null 2>&1; then
            brew install git
        fi
        ;;
    Linux)
        init_script="init-linux.sh"
        if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
            install_git_linux
        fi
        ;;
    *)
        echo "Error: unsupported operating system: $(uname -s)" >&2
        exit 1
        ;;
esac

if [ -d "$directory/.git" ]; then
    git -C "$directory" pull --ff-only
elif [ -e "$directory" ]; then
    echo "Error: $directory already exists and is not a Git checkout" >&2
    exit 1
else
    mkdir -p "$(dirname "$directory")"
    git clone "$repository" "$directory"
fi

exec bash "$directory/$init_script"
