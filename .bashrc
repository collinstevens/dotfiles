# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

export PATH="$HOME/.local/bin:$PATH"

if [[ "$PWD" == "$HOME" && -d "$HOME/projects" ]]; then
    cd "$HOME/projects"
fi

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias cj='container=lxc firejail --profile=~/claude.firejail.profile --read-write=$PWD claude --dangerously-skip-permissions'

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

eval "$(gh completion -s bash)"

[[ -x "$HOME/.local/bin/mise" ]] && eval "$("$HOME/.local/bin/mise" activate bash)"

SSH_ENV="$HOME/.ssh/agent-environment"
SSH_KEY="$HOME/.ssh/id_ed25519"

add_ssh_key() {
    if [ -t 0 ]; then
        ssh-add "$SSH_KEY"
    else
        ssh-add "$SSH_KEY" >/dev/null 2>&1
    fi
}

start_ssh_agent() {
    echo "Starting ssh-agent..."
    eval "$(ssh-agent -s)" >/dev/null
    echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > "$SSH_ENV"
    echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> "$SSH_ENV"
    chmod 600 "$SSH_ENV"

    add_ssh_key
}

agent_can_connect() {
    [ -n "${SSH_AUTH_SOCK:-}" ] || return 1
    [ -S "$SSH_AUTH_SOCK" ] || return 1

    ssh-add -l >/dev/null 2>&1

    case $? in
        0|1) return 0 ;;
        *) return 1 ;;
    esac
}

if [ -f "$SSH_ENV" ]; then
    . "$SSH_ENV" >/dev/null
fi

if agent_can_connect; then
    ssh-add -l >/dev/null 2>&1 || add_ssh_key
else
    rm -f "$SSH_ENV"
    start_ssh_agent
fi

# Remove every PATH entry starting with /mnt/ (to avoid WSL issues)
PATH="$(
  printf '%s\n' "$PATH" \
    | tr ':' '\n' \
    | grep -v '^/mnt/' \
    | paste -sd: -
)"
export PATH

export COLORTERM=truecolor

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# Amp CLI
export PATH="$HOME/.amp/bin:$PATH"

export CLAUDE_CONFIG_DIR="$HOME/.claude"

command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"

# Allow `code .` from WSL without importing the entire Windows PATH
export PATH="$PATH:/mnt/c/Program Files/Microsoft VS Code/bin"
