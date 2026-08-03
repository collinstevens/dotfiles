#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

links=(
    ".zprofile:$HOME/.zprofile"
    ".gitconfig:$HOME/.gitconfig"
    ".gitconfig-macos:$HOME/.gitconfig-macos"
    ".gitignore-global:$HOME/.gitignore-global"
    "linearmouse/linearmouse.json:$HOME/.config/linearmouse/linearmouse.json"
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

load_launchagent() {
    label="$1"
    source_file="$SCRIPT_DIR/launchagents/$label.plist"
    target="$HOME/Library/LaunchAgents/$label.plist"
    mkdir -p "$(dirname "$target")"
    cp "$source_file" "$target"
    launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$target"
    echo "Loaded: $label"
}

load_launchagent com.collin.swap-fn-ctrl

defaults import com.googlecode.iterm2 "$SCRIPT_DIR/iterm2/com.googlecode.iterm2.plist"
echo "Imported: iterm2/com.googlecode.iterm2.plist -> com.googlecode.iterm2"

echo "Done."
