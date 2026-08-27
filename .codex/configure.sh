#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
codex_config="${1:-$HOME/.codex/config.toml}"
git_ignore_path="${2:-$HOME/.config/git/ignore}"
managed_config="${SCRIPT_DIR}/managed-config.toml"
permissions="${SCRIPT_DIR}/permissions.toml"
merge_expression='((select(fileIndex == 0) // {}) | del(.sandbox_workspace_write, .permissions.workspace_gitignore)) * (select(fileIndex == 1)) * (select(fileIndex == 2) | .permissions.workspace_gitignore.filesystem = {(strenv(GIT_IGNORE_PATH)): "read"})'

if ! command -v yq >/dev/null 2>&1; then
    echo "yq is required to update $codex_config" >&2
    exit 1
fi
for fragment in "$managed_config" "$permissions"; do
    if [ ! -f "$fragment" ]; then
        echo "Codex configuration fragment not found: $fragment" >&2
        exit 1
    fi
done

yq_path="$(command -v yq)"
codex_config_dir="$(dirname "$codex_config")"
mkdir -p "$codex_config_dir"
if [ ! -f "$codex_config" ]; then
    : > "$codex_config"
fi

codex_config_tmp="$(mktemp "${codex_config}.tmp.XXXXXX")"
if ! GIT_IGNORE_PATH="$git_ignore_path" "$yq_path" eval-all --input-format toml --output-format toml "$merge_expression" "$codex_config" "$managed_config" "$permissions" > "$codex_config_tmp"; then
    rm -f -- "$codex_config_tmp"
    exit 1
fi
if [ ! -s "$codex_config_tmp" ]; then
    echo "Unable to merge Codex settings with yq" >&2
    rm -f -- "$codex_config_tmp"
    exit 1
fi

mv -f -- "$codex_config_tmp" "$codex_config"
echo "Updated Codex configuration: $codex_config"
