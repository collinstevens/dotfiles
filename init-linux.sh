#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v starship >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/starship" ]; then
    curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
fi

links=(
    ".bashrc:$HOME/.bashrc"
    ".gitconfig:$HOME/.gitconfig"
    ".gitignore-global:$HOME/.gitignore-global"
    ".config/starship-linux.toml:$HOME/.config/starship.toml"
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

ptyxis_conf="${SCRIPT_DIR}/ptyxis.conf"
if [ -f "$ptyxis_conf" ] && command -v dconf >/dev/null 2>&1; then
    dconf load /org/gnome/Ptyxis/ < "$ptyxis_conf"
    echo "Loaded Ptyxis settings: $ptyxis_conf"
fi

echo "Done."
