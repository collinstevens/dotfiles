#!/bin/bash
set -euo pipefail

repository="${DOTFILES_REPOSITORY:-https://github.com/collinstevens/dotfiles.git}"
directory="${DOTFILES_DIR:-$HOME/projects/collinstevens/dotfiles}"
ssh_key="$HOME/.ssh/id_ed25519"

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

install_prerequisites_linux() {
    if command -v apt-get >/dev/null 2>&1; then
        run_as_root apt-get update
        run_as_root apt-get install -y ca-certificates curl git openssh-client
    elif command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y curl git openssh-clients
    elif command -v pacman >/dev/null 2>&1; then
        run_as_root pacman -S --needed --noconfirm curl git openssh
    elif command -v zypper >/dev/null 2>&1; then
        run_as_root zypper --non-interactive install curl git openssh-clients
    elif command -v apk >/dev/null 2>&1; then
        run_as_root apk add bash curl git openssh-keygen
    else
        echo "Error: no supported package manager found; install git, curl, and ssh-keygen and rerun the bootstrap" >&2
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
        for command_name in git curl ssh-keygen; do
            if ! command -v "$command_name" >/dev/null 2>&1; then
                install_prerequisites_linux
                break
            fi
        done
        ;;
    *)
        echo "Error: unsupported operating system: $(uname -s)" >&2
        exit 1
        ;;
esac

if [ ! -e "$ssh_key" ]; then
    mkdir -p "$(dirname "$ssh_key")"
    chmod 700 "$(dirname "$ssh_key")"
    ssh_key_comment="$(id -un)-$(uname -n | cut -d. -f1)"
    ssh-keygen -t ed25519 -f "$ssh_key" -C "$(printf '%s' "$ssh_key_comment" | tr '[:upper:]' '[:lower:]')"
    echo "Created SSH key: $ssh_key.pub"
fi

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
