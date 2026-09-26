#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

run_as_root() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

install_system_package() {
    local command_name="$1"
    local package_name="$command_name"

    if command -v "$command_name" >/dev/null 2>&1; then
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        if [ "$command_name" = "gh" ]; then
            run_as_root apt-get update
            run_as_root apt-get install -y ca-certificates curl
            local keyring_download
            keyring_download="$(mktemp)"
            if ! curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$keyring_download"; then
                rm -f "$keyring_download"
                echo "Error: unable to download the GitHub CLI package signing key" >&2
                exit 1
            fi
            run_as_root install -d -m 0755 /etc/apt/keyrings /etc/apt/sources.list.d
            run_as_root install -m 0644 "$keyring_download" /etc/apt/keyrings/githubcli-archive-keyring.gpg
            rm -f "$keyring_download"
            printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" |
                run_as_root tee /etc/apt/sources.list.d/github-cli.list >/dev/null
        fi
        run_as_root apt-get update
        run_as_root apt-get install -y "$package_name"
    elif command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y "$package_name"
    elif command -v pacman >/dev/null 2>&1; then
        if [ "$command_name" = "gh" ]; then
            package_name="github-cli"
        fi
        run_as_root pacman -S --needed --noconfirm "$package_name"
    elif command -v zypper >/dev/null 2>&1; then
        run_as_root zypper --non-interactive install "$package_name"
    elif command -v apk >/dev/null 2>&1; then
        if [ "$command_name" = "gh" ]; then
            package_name="github-cli"
        fi
        run_as_root apk add "$package_name"
    else
        echo "Error: no supported package manager found; install $command_name and rerun this script" >&2
        exit 1
    fi

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Error: $command_name was installed but is not available" >&2
        exit 1
    fi
}

install_system_package git
install_system_package gh

if ! gh stack --help >/dev/null 2>&1; then
    if ! gh extension install github/gh-stack; then
        echo "Error: unable to install the gh stack extension" >&2
        exit 1
    fi
fi

install_system_package tmux

if ! command -v mise >/dev/null 2>&1; then
    curl -fsSL https://mise.run | sh
fi
mise --version

mise_path_line='export PATH="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$HOME/.local/bin:$PATH"'
bash_login_profile="$HOME/.profile"
for profile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
    if [ -f "$profile" ]; then
        bash_login_profile="$profile"
        break
    fi
done
for profile in "$HOME/.profile" "$bash_login_profile"; do
    if ! grep -Fqx "$mise_path_line" "$profile" 2>/dev/null; then
        printf '\n%s\n' "$mise_path_line" >> "$profile"
    fi
done

if ! command -v yq >/dev/null 2>&1; then
    case "$(uname -m)" in
        x86_64) yq_arch="amd64" ;;
        aarch64|arm64) yq_arch="arm64" ;;
        armv7l) yq_arch="arm" ;;
        i386|i686) yq_arch="386" ;;
        *)
            echo "Error: unsupported architecture for yq: $(uname -m)" >&2
            exit 1
            ;;
    esac

    yq_download="$(mktemp)"
    if ! curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${yq_arch}" -o "$yq_download"; then
        rm -f "$yq_download"
        echo "Error: unable to download yq" >&2
        exit 1
    fi
    install -m 0755 "$yq_download" "$HOME/.local/bin/yq"
    rm -f "$yq_download"
fi

links=(
    ".bashrc:$HOME/.bashrc"
    ".tmux.conf:$HOME/.tmux.conf"
    ".gitconfig:$HOME/.gitconfig"
    ".gitignore-global:$HOME/.gitignore-global"
    ".claude/settings-unix.json:$HOME/.claude/settings.json"
    ".claude/statusline-command.sh:$HOME/.claude/statusline-command.sh"
    "shared/AGENTS.md:$HOME/.claude/CLAUDE.md"
    "shared/skills/narrative-rewrite/SKILL.md:$HOME/.claude/skills/narrative-rewrite/SKILL.md"
    "shared/AGENTS.md:$HOME/.codex/AGENTS.md"
    "shared/skills/narrative-rewrite/SKILL.md:$HOME/.codex/skills/narrative-rewrite/SKILL.md"
    "shared/skills/narrative-rewrite/agents/openai.yaml:$HOME/.codex/skills/narrative-rewrite/agents/openai.yaml"
    ".codex/rules/default.rules:$HOME/.codex/rules/default.rules"
    ".grok/config.toml:$HOME/.grok/config.toml"
    "shared/AGENTS.md:$HOME/.grok/AGENTS.md"
    ".config/opencode/opencode.jsonc:$HOME/.config/opencode/opencode.jsonc"
    ".claude/keybindings.json:$HOME/.claude/keybindings.json"
)

system_files=(
    "wsl.conf:/etc/wsl.conf"
)

for link in "${links[@]}"; do
    source_file="${SCRIPT_DIR}/${link%%:*}"
    target="${link##*:}"

    if [ ! -e "$source_file" ]; then
        echo "Error: Source file not found: $source_file" >&2
        exit 1
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        rm -f "$target"
        echo "Removed existing: $target"
    fi

    mkdir -p "$(dirname "$target")"
    cp "$source_file" "$target"
    echo "Copied: $source_file -> $target"
done

for link in "${system_files[@]}"; do
    source_file="${SCRIPT_DIR}/${link%%:*}"
    target="${link##*:}"

    if [ ! -e "$source_file" ]; then
        echo "Error: Source file not found: $source_file" >&2
        exit 1
    fi

    if [ -w "$(dirname "$target")" ]; then
        install -m 0644 "$source_file" "$target"
    else
        sudo install -m 0644 "$source_file" "$target"
    fi

    echo "Copied: $source_file -> $target"
done

bash "$SCRIPT_DIR/.codex/configure.sh"
bash "$SCRIPT_DIR/ssh-keys/authorize.sh"

ptyxis_conf="${SCRIPT_DIR}/ptyxis.conf"
if [ -f "$ptyxis_conf" ] && command -v dconf >/dev/null 2>&1; then
    dconf load /org/gnome/Ptyxis/ < "$ptyxis_conf"
    echo "Loaded Ptyxis settings: $ptyxis_conf"
fi

echo "Done."
