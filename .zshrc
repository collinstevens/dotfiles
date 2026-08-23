export PATH="$HOME/.local/bin:$PATH"

if [[ "$PWD" == "$HOME" && -d "$HOME/projects" ]]; then
    cd "$HOME/projects"
fi

bindkey "^[[3~" delete-char

command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

PROMPT='%1~ %# '
