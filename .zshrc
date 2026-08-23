export PATH="$HOME/.local/bin:$PATH"

if [[ "$PWD" == "$HOME" && -d "$HOME/src" ]]; then
    cd "$HOME/src"
fi

bindkey "^[[3~" delete-char

command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

PROMPT='%1~ %# '
