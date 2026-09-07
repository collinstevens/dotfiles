export PATH="$HOME/.local/bin:$PATH"

if [[ "$PWD" == "$HOME" && -d "$HOME/projects" ]]; then
    cd "$HOME/projects"
fi

mktemp() {
    if [ "$#" -gt 1 ]; then
        printf 'Usage: mktemp [prefix]\n' >&2
        return 1
    fi

    command mktemp -d "${TMPDIR:-/tmp}/${1:-}XXXXXXXXXX"
}

cdtemp() {
    local directory
    directory=$(mktemp "$@") || return
    builtin cd -- "$directory"
}

cddir() {
    if [ "$#" -ne 1 ] || [ -z "$1" ]; then
        printf 'Usage: cddir <directory>\n' >&2
        return 1
    fi

    mkdir -p -- "$1" && builtin cd -- "$1"
}

bindkey "^[[3~" delete-char

command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
