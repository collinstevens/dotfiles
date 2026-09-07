eval "$(/opt/homebrew/bin/brew shellenv zsh)"
export PATH="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$HOME/.local/bin:$PATH"
