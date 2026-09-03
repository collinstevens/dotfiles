#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v starship >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/starship" ]; then
    curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
fi

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
    ".gitconfig:$HOME/.gitconfig"
    ".gitignore-global:$HOME/.gitignore-global"
    ".claude/settings-unix.json:$HOME/.claude/settings.json"
    ".claude/statusline-command.sh:$HOME/.claude/statusline-command.sh"
    ".claude/CLAUDE.md:$HOME/.claude/CLAUDE.md"
    ".codex/AGENTS.md:$HOME/.codex/AGENTS.md"
    ".codex/rules/default.rules:$HOME/.codex/rules/default.rules"
    ".grok/config.toml:$HOME/.grok/config.toml"
    ".codex/AGENTS.md:$HOME/.grok/AGENTS.md"
    ".config/opencode/opencode.jsonc:$HOME/.config/opencode/opencode.jsonc"
    ".config/starship-linux.toml:$HOME/.config/starship.toml"
    ".claude/keybindings.json:$HOME/.claude/keybindings.json"
)

skill_links=(
    "vendor/humanlayer-skills/plugins/show-me/skills/show-me:$HOME/.claude/skills/show-me"
    "vendor/humanlayer-skills/plugins/show-me/skills/show-me:$HOME/.codex/skills/show-me"
    "vendor/humanlayer-skills/plugins/show-me/skills/show-me:$HOME/.grok/skills/show-me"
)

git -C "$SCRIPT_DIR" submodule update --init --recursive -- vendor/humanlayer-skills

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

for link in "${skill_links[@]}"; do
    source_directory="${SCRIPT_DIR}/${link%%:*}"
    target="${link##*:}"

    if [ ! -d "$source_directory" ]; then
        echo "Error: Source directory not found: $source_directory" >&2
        exit 1
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        rm -rf "$target"
        echo "Removed existing: $target"
    fi

    mkdir -p "$(dirname "$target")"
    cp -R "$source_directory" "$target"
    echo "Copied: $source_directory -> $target"
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

gnome_terminal_conf="${SCRIPT_DIR}/gnome-terminal.conf"
if [ -f "$gnome_terminal_conf" ] && command -v dconf >/dev/null 2>&1; then
    dconf load /org/gnome/terminal/legacy/ < "$gnome_terminal_conf"
    echo "Loaded GNOME Terminal settings: $gnome_terminal_conf"
fi

echo "Done."
