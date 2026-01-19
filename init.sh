#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

links=(
    ".gitconfig:$HOME/.gitconfig"
    ".gitconfig-linux:$HOME/.gitconfig-linux"
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

    ln -s "$source_file" "$target"
    echo "Linked: $target -> $source_file"
done

echo "Done."
