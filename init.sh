#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

links=(
    ".bashrc:$HOME/.bashrc"
    ".gitconfig:$HOME/.gitconfig"
    ".gitconfig-linux:$HOME/.gitconfig-linux"
    ".claude/settings.json:$HOME/.claude/settings.json"
    ".claude/CLAUDE.md:$HOME/.claude/CLAUDE.md"
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

gnome_terminal_conf="${SCRIPT_DIR}/gnome-terminal.conf"
if [ -f "$gnome_terminal_conf" ] && command -v dconf >/dev/null 2>&1; then
    dconf load /org/gnome/terminal/legacy/ < "$gnome_terminal_conf"
    echo "Loaded GNOME Terminal settings: $gnome_terminal_conf"
fi

echo "Done."
