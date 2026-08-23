# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

if [[ "$PWD" == "$HOME" && -d "$HOME/src" ]]; then
    cd "$HOME/src"
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

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

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

PS1='\[\e[01;32m\]\w\[\e[00m\]\$ '

# Allow `code .` from WSL without importing the entire Windows PATH
export PATH="$PATH:/mnt/c/Program Files/Microsoft VS Code/bin"
