export PATH="$HOME/.local/bin:$HOME/.dotnet/tools:$PATH"

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

alias cy='claude --dangerously-skip-permissions'
alias cys='claude --dangerously-skip-permissions --setting-sources=user'

autoload -Uz compinit && compinit

bindkey "^[[3~" delete-char
bindkey "^H" backward-kill-word
bindkey "^[[3;5~" kill-word
bindkey "^[[3;3~" kill-word
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[1;3C" forward-word
bindkey "^[[1;3D" backward-word
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[[1~" beginning-of-line
bindkey "^[[4~" end-of-line
stty -ixon
bindkey "^S" history-incremental-search-forward

command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
