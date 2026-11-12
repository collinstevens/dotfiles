#!/bin/bash
set -euo pipefail

script_source="${BASH_SOURCE[0]:-}"
dotfiles_repository="${DOTFILES_REPOSITORY:-https://github.com/collinstevens/dotfiles.git}"
dotfiles_dir="${DOTFILES_DIR:-$HOME/projects/collinstevens/dotfiles}"

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
        if [ "$command_name" = "ssh-keygen" ]; then
            package_name="openssh-client"
        fi
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
        if [ "$command_name" = "ssh-keygen" ]; then
            package_name="openssh-clients"
        fi
        run_as_root dnf install -y "$package_name"
    elif command -v pacman >/dev/null 2>&1; then
        if [ "$command_name" = "gh" ]; then
            package_name="github-cli"
        elif [ "$command_name" = "ssh-keygen" ]; then
            package_name="openssh"
        fi
        run_as_root pacman -S --needed --noconfirm "$package_name"
    elif command -v zypper >/dev/null 2>&1; then
        if [ "$command_name" = "ssh-keygen" ]; then
            package_name="openssh-clients"
        fi
        run_as_root zypper --non-interactive install "$package_name"
    elif command -v apk >/dev/null 2>&1; then
        if [ "$command_name" = "gh" ]; then
            package_name="github-cli"
        elif [ "$command_name" = "ssh-keygen" ]; then
            package_name="openssh-keygen"
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
install_system_package curl
install_system_package ssh-keygen

ssh_key="$HOME/.ssh/id_ed25519"
if [ ! -e "$ssh_key" ]; then
    mkdir -p "$(dirname "$ssh_key")"
    chmod 700 "$(dirname "$ssh_key")"
    ssh_key_comment="$(id -un)-$(uname -n | cut -d. -f1)"
    ssh-keygen -t ed25519 -f "$ssh_key" -C "$(printf '%s' "$ssh_key_comment" | tr '[:upper:]' '[:lower:]')" -N ""
    echo "Created SSH key: $ssh_key.pub"
fi

if [ -z "$script_source" ] || [ ! -f "$script_source" ]; then
    if [ -e "$dotfiles_dir/.git" ]; then
        if ! git -C "$dotfiles_dir" pull --ff-only; then
            echo "Warning: unable to update $dotfiles_dir; continuing with the existing checkout" >&2
        fi
    elif [ -e "$dotfiles_dir" ]; then
        echo "Error: $dotfiles_dir already exists and is not a Git checkout" >&2
        exit 1
    else
        mkdir -p "$(dirname "$dotfiles_dir")"
        git clone "$dotfiles_repository" "$dotfiles_dir"
    fi
    exec bash "$dotfiles_dir/init-linux.sh"
fi

SCRIPT_DIR="$(cd "$(dirname "$script_source")" && pwd)"

install_system_package gh

if ! gh stack --help >/dev/null 2>&1; then
    if ! gh extension install github/gh-stack; then
        echo "Error: unable to install the gh stack extension" >&2
        exit 1
    fi
fi

github_key_scopes="admin:public_key,admin:ssh_signing_key"
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    gh auth login --hostname github.com --git-protocol https --web --scopes "$github_key_scopes"
fi
if ! gh api user/keys --silent >/dev/null 2>&1 || ! gh api user/ssh_signing_keys --silent >/dev/null 2>&1; then
    gh auth refresh --hostname github.com --scopes "$github_key_scopes"
fi

ssh_public_key_path="$HOME/.ssh/id_ed25519.pub"
ssh_public_key="$(awk '{ print $1 " " $2 }' "$ssh_public_key_path")"
ssh_key_title="$(awk '{ print $3 }' "$ssh_public_key_path")"
if [ -z "$ssh_key_title" ]; then
    ssh_key_title="$(id -un)-$(uname -n | cut -d. -f1)"
    ssh_key_title="$(printf '%s' "$ssh_key_title" | tr '[:upper:]' '[:lower:]')"
fi
for github_key in authentication:user/keys signing:user/ssh_signing_keys; do
    github_key_type="${github_key%%:*}"
    registered_keys="$(gh api "${github_key#*:}" --paginate --jq '.[].key')"
    if ! grep -Fqx -- "$ssh_public_key" <<< "$registered_keys"; then
        gh ssh-key add "$ssh_public_key_path" --title "$ssh_key_title" --type "$github_key_type"
    fi
done

github_host_keys="$(gh api meta --jq '.ssh_keys[]')"
if [ -z "$github_host_keys" ]; then
    echo "Error: unable to read the GitHub SSH host keys" >&2
    exit 1
fi
known_hosts="$HOME/.ssh/known_hosts"
(umask 077; touch "$known_hosts")
while IFS= read -r github_host_key; do
    if ! grep -Fqx -- "github.com $github_host_key" "$known_hosts"; then
        if [ -s "$known_hosts" ] && [ -n "$(tail -c 1 "$known_hosts")" ]; then
            printf '\n' >> "$known_hosts"
        fi
        printf 'github.com %s\n' "$github_host_key" >> "$known_hosts"
        echo "Added GitHub SSH host key -> $known_hosts"
    fi
done <<< "$github_host_keys"

origin_url="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)"
if [[ "$origin_url" =~ ^https://github\.com/([^/]+/[^/]+)$ ]]; then
    ssh_origin_url="git@github.com:${BASH_REMATCH[1]%.git}.git"
    git -C "$SCRIPT_DIR" remote set-url origin "$ssh_origin_url"
    if git -C "$SCRIPT_DIR" ls-remote --exit-code origin HEAD >/dev/null 2>&1; then
        echo "Switched origin to SSH: $ssh_origin_url"
    else
        git -C "$SCRIPT_DIR" remote set-url origin "$origin_url"
        echo "Warning: unable to reach $ssh_origin_url; keeping origin at $origin_url" >&2
    fi
fi

install_system_package tmux

if ! command -v mise >/dev/null 2>&1; then
    curl -fsSL https://mise.run | sh
fi
mise --version

mise_tools=(
    aqua:temporalio/cli
    aspire
    aube
    bun
    dotnet
    git-lfs
    github:temporalio/cloud-cli
    java
    jq
    node
    npm
    npm:wrangler
    pnpm
    python
    rg
    yq
)

mise use --global "${mise_tools[@]/%/@latest}"
for mise_tool in "${mise_tools[@]}"; do
    mise config set --global "tools.$mise_tool.auto_update" false
done
mise settings unset self_update.auto

mise exec dotnet@latest -- dotnet tool install --global dotnet-counters --allow-roll-forward
mise exec dotnet@latest -- dotnet tool install --global dotnet-coverage --allow-roll-forward
mise exec dotnet@latest -- dotnet tool install --global dotnet-debug --allow-roll-forward
mise exec dotnet@latest -- dotnet tool install --global dotnet-dump --allow-roll-forward
mise exec dotnet@latest -- dotnet tool install --global dotnet-gcdump --allow-roll-forward
mise exec dotnet@latest -- dotnet tool install --global dotnet-monitor --allow-roll-forward
mise exec dotnet@latest -- dotnet tool install --global dotnet-trace --allow-roll-forward
mise exec dotnet@latest -- dotnet tool install --global dotnet-stack --allow-roll-forward
mise exec dotnet@latest -- dotnet tool install --global dotnet-symbol
mise exec dotnet@latest -- dotnet tool install --global dotnet-debugger-extensions --allow-roll-forward
mise exec dotnet@latest -- dotnet tool install --global dotnet-sos --allow-roll-forward
mise exec dotnet@latest -- dotnet tool install --global dotnet-dsrouter --allow-roll-forward

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

dotnet_path_line='export PATH="$HOME/.dotnet/tools:$PATH"'
for profile in "$HOME/.profile" "$bash_login_profile"; do
    if ! grep -Fqx "$dotnet_path_line" "$profile" 2>/dev/null; then
        printf '\n%s\n' "$dotnet_path_line" >> "$profile"
    fi
done

if ! command -v claude >/dev/null 2>&1; then
    curl -fsSL https://claude.ai/install.sh | bash
    if ! command -v claude >/dev/null 2>&1; then
        echo "Error: Claude Code was installed but claude is not available" >&2
        exit 1
    fi
fi

links=(
    ".bashrc:$HOME/.bashrc"
    ".tmux.conf:$HOME/.tmux.conf"
    ".gitconfig:$HOME/.gitconfig"
    ".gitignore-global:$HOME/.gitignore-global"
    ".claude/settings-unix.json:$HOME/.claude/settings.json"
    ".claude/statusline-command.sh:$HOME/.claude/statusline-command.sh"
    ".claude/no-agent-summary.js:$HOME/.claude/no-agent-summary.js"
    "shared/AGENTS.md:$HOME/.claude/CLAUDE.md"
    "shared/skills/narrative-rewrite/SKILL.md:$HOME/.claude/skills/narrative-rewrite/SKILL.md"
    "shared/skills/git-cleanup/SKILL.md:$HOME/.claude/skills/git-cleanup/SKILL.md"
    "shared/AGENTS.md:$HOME/.codex/AGENTS.md"
    "shared/skills/narrative-rewrite/SKILL.md:$HOME/.codex/skills/narrative-rewrite/SKILL.md"
    "shared/skills/git-cleanup/SKILL.md:$HOME/.codex/skills/git-cleanup/SKILL.md"
    "shared/skills/narrative-rewrite/agents/openai.yaml:$HOME/.codex/skills/narrative-rewrite/agents/openai.yaml"
    "shared/skills/git-cleanup/agents/openai.yaml:$HOME/.codex/skills/git-cleanup/agents/openai.yaml"
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

mise exec yq@latest -- bash "$SCRIPT_DIR/.codex/configure.sh"
bash "$SCRIPT_DIR/.claude/configure-mcp.sh"
bash "$SCRIPT_DIR/ssh-keys/authorize.sh"

ptyxis_conf="${SCRIPT_DIR}/ptyxis.conf"
if [ -f "$ptyxis_conf" ] && command -v dconf >/dev/null 2>&1; then
    dconf load /org/gnome/Ptyxis/ < "$ptyxis_conf"
    echo "Loaded Ptyxis settings: $ptyxis_conf"
fi

echo "Done."
