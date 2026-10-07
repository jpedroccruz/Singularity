#
# ~/.bashrc
#

[[ $- != *i* ]] && return

# Aliases
alias ls='lsd -hl'
alias grep='grep --color=auto'
alias ff='fastfetch'
alias cd='z'

PS1='[\u@\h \W]\$ '

# Evals
eval "$(zoxide init bash)"
eval "$(starship init bash)"
