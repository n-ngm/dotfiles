# Ctrl+D でシェルが閉じないようにする
setopt IGNORE_EOF

# Disable XON/XOFF flow control (free up Ctrl+Q/Ctrl+S)
stty -ixon -ixoff

# Ctrl+D: 空入力時は exit、入力ありの時はデフォルト動作(補完候補表示)
function _ctrl_d_handler() {
  if [[ -z "$BUFFER" ]]; then
    BUFFER="exit"
    zle end-of-line
  else
    zle delete-char-or-list
  fi
}
zle -N _ctrl_d_handler
bindkey '^D' _ctrl_d_handler

# envs
export LANG=ja_JP.UTF-8
source "${HOME}/.env"


# alias
if [ -e "$HOME/.alias" ]
then
    source "$HOME/.alias"
fi

# Claude Agent: skip heavy initialization
if [[ -n "$CLAUDE_AGENT" ]]; then
  export PATH="$HOME/.bun/bin:$HOME/.local/bin:$HOME/.antigravity/antigravity/bin:$PATH"
  export ANYENV_ROOT="$HOME/.anyenv"
  export PATH="$ANYENV_ROOT/bin:$PATH"
  eval "$(anyenv init -)" 2>/dev/null
  return
fi

eval "$(direnv hook zsh)"

# sheldon
eval "$(sheldon source)"

# prompt
setopt PROMPT_SUBST
autoload -Uz add-zsh-hook

function _update_git_branch() {
  _git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
}
add-zsh-hook precmd _update_git_branch

function _prompt_git() {
  [[ -n "$_git_branch" ]] && echo " %F{cyan}${_git_branch}%f"
}

PROMPT='%F{blue}%~%f$(_prompt_git)
❯ '

function _transient_accept_line() {
  PROMPT='❯ '
  zle reset-prompt
  PROMPT='%F{blue}%~%f$(_prompt_git)
❯ '
  zle .accept-line
}
zle -N accept-line _transient_accept_line

# history
export HISTFILE=~/.zsh_history
export HISTSIZE=10000
export SAVEHIST=100000


# path
# export PATH="$HOME/bin:$PATH"

# iterm2
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh" || true



###-begin-npm-completion-###
#
# npm command completion script
#
# Installation: npm completion >> ~/.bashrc  (or ~/.zshrc)
# Or, maybe: npm completion > /usr/local/etc/bash_completion.d/npm
#

if type complete &>/dev/null; then
  _npm_completion () {
    local words cword
    if type _get_comp_words_by_ref &>/dev/null; then
      _get_comp_words_by_ref -n = -n @ -n : -w words -i cword
    else
      cword="$COMP_CWORD"
      words=("${COMP_WORDS[@]}")
    fi

    local si="$IFS"
    if ! IFS=$'\n' COMPREPLY=($(COMP_CWORD="$cword" \
                           COMP_LINE="$COMP_LINE" \
                           COMP_POINT="$COMP_POINT" \
                           npm completion -- "${words[@]}" \
                           2>/dev/null)); then
      local ret=$?
      IFS="$si"
      return $ret
    fi
    IFS="$si"
    if type __ltrim_colon_completions &>/dev/null; then
      __ltrim_colon_completions "${words[cword]}"
    fi
  }
  complete -o default -F _npm_completion npm
elif type compdef &>/dev/null; then
  _npm_completion() {
    local si=$IFS
    compadd -- $(COMP_CWORD=$((CURRENT-1)) \
                 COMP_LINE=$BUFFER \
                 COMP_POINT=0 \
                 npm completion -- "${words[@]}" \
                 2>/dev/null)
    IFS=$si
  }
  compdef _npm_completion npm
elif type compctl &>/dev/null; then
  _npm_completion () {
    local cword line point words si
    read -Ac words
    read -cn cword
    let cword-=1
    read -l line
    read -ln point
    si="$IFS"
    if ! IFS=$'\n' reply=($(COMP_CWORD="$cword" \
                       COMP_LINE="$line" \
                       COMP_POINT="$point" \
                       npm completion -- "${words[@]}" \
                       2>/dev/null)); then

      local ret=$?
      IFS="$si"
      return $ret
    fi
    IFS="$si"
  }
  compctl -K _npm_completion npm
fi
###-end-npm-completion-###

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# tmux
function _tmux_refresh() {
    if [ ! -z $TMUX ]; then
        tmux refresh-client -S
    fi
}
add-zsh-hook precmd _tmux_refresh

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
eval "$(mise activate zsh)"

export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
export NODE_OPTIONS="--dns-result-order=ipv4first"
