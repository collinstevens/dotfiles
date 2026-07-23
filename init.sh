#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

upsert_codex_permissions() {
    local codex_config="$HOME/.codex/config.toml"
    local codex_config_dir
    local codex_config_tmp
    local codex_permissions="$SCRIPT_DIR/.codex/permissions.toml"
    local git_ignore_path="$HOME/.config/git/ignore"
    local merge_expression
    local yq_path

    codex_config_dir="$(dirname "$codex_config")"
    merge_expression='((select(fileIndex == 0) // {}) | del(.sandbox_workspace_write, .permissions.workspace_gitignore)) * (select(fileIndex == 1) | .permissions.workspace_gitignore.filesystem = {(strenv(GIT_IGNORE_PATH)): "read"})'

    if ! command -v mise >/dev/null 2>&1; then
        echo "mise is required to update $codex_config" >&2
        return 1
    fi
    if [ ! -f "$codex_permissions" ]; then
        echo "Codex permissions fragment not found: $codex_permissions" >&2
        return 1
    fi
    mise install yq@latest
    yq_path="$(mise which yq --tool yq@latest)"

    mkdir -p "$codex_config_dir"
    if [ ! -f "$codex_config" ]; then
        : > "$codex_config"
    fi
    codex_config_tmp="$(mktemp "${codex_config}.tmp.XXXXXX")"
    if ! GIT_IGNORE_PATH="$git_ignore_path" "$yq_path" eval-all --input-format toml --output-format toml "$merge_expression" "$codex_config" "$codex_permissions" > "$codex_config_tmp"; then
        rm -f -- "$codex_config_tmp"
        return 1
    fi
    if [ ! -s "$codex_config_tmp" ]; then
        echo "Unable to merge Codex settings with yq" >&2
        rm -f -- "$codex_config_tmp"
        return 1
    fi

    mv -f -- "$codex_config_tmp" "$codex_config"
    echo "Updated Codex permissions: $codex_config"
}

links=(
    ".bashrc:$HOME/.bashrc"
    ".gitconfig:$HOME/.gitconfig"
    ".gitconfig-linux:$HOME/.gitconfig-linux"
    "mise-global-config.toml:$HOME/.config/mise/config.toml"
    ".claude/settings.json:$HOME/.claude/settings.json"
    ".claude/CLAUDE.md:$HOME/.claude/CLAUDE.md"
    ".codex/AGENTS.md:$HOME/.codex/AGENTS.md"
    ".codex/rules/default.rules:$HOME/.codex/rules/default.rules"
    ".grok/config.toml:$HOME/.grok/config.toml"
    ".codex/AGENTS.md:$HOME/.grok/AGENTS.md"
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

upsert_codex_permissions

gnome_terminal_conf="${SCRIPT_DIR}/gnome-terminal.conf"
if [ -f "$gnome_terminal_conf" ] && command -v dconf >/dev/null 2>&1; then
    dconf load /org/gnome/terminal/legacy/ < "$gnome_terminal_conf"
    echo "Loaded GNOME Terminal settings: $gnome_terminal_conf"
fi

echo "Done."
