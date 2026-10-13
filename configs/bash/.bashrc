#
# ~/.bashrc
#

_kc() { XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)} secret-tool lookup kc "$1" 2>/dev/null; }
gh() { GH_TOKEN=$(_kc GITHUB_TOKEN_BLUEHORSE) command gh "$@"; }

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

alias ls='ls --color=auto'
alias grep='grep --color=auto'
export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"
eval "$(zoxide init bash)"

# Создать новый alias: a <имя> <команда>
a() {
    [[ $# -lt 2 ]] && echo "usage: a <name> <command>" && return 1
    local name="$1"; shift
    local cmd="$*"
    alias "$name=$cmd"
    echo "alias $name='$cmd'" >> ~/.bashrc
    echo "alias $name='$cmd'"
}
#eval "$(starship init bash)"
alias cc='claude --dangerously-skip-permissions'
alias p='sudo pacman -S'
alias tutor='nvim /usr/share/vim/vim92/tutor/tutor1'
alias brc='nano ~/.bashrc'
alias sb='source ~/.bashrc'
alias l='ls'
alias vol='pavucontrol &'
alias sbc='kitty @ get-text --extent all | wl-copy'

. "$HOME/.local/bin/env"
