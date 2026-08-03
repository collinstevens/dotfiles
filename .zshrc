export PATH="$HOME/.local/bin:$PATH"

if [[ "$PWD" == "$HOME" && -d "$HOME/projects" ]]; then
    cd "$HOME/projects"
fi

bindkey "^[[3~" delete-char
