# Ctrl+D でシェルが閉じないようにする
setopt IGNORE_EOF

# envs
export LANG=ja_JP.UTF-8
source "${HOME}/.env"


# Homebrew
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# alias
if [ -e "$HOME/.alias" ]
then
    source "$HOME/.alias"
fi

# Claude Agent: skip heavy initialization
if [[ -n "$CLAUDE_AGENT" ]]; then
  export PATH="$HOME/.bun/bin:$HOME/.local/bin:$HOME/.antigravity/antigravity/bin:$PATH"
  if [ -e "$HOME/.anyenv" ]; then
    export PATH="$HOME/.anyenv/bin:$PATH"
    eval "$(anyenv init -)" 2>/dev/null
  fi
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

# anyenv
if [ -e "$HOME/.anyenv" ]
then
    export ANYENV_ROOT="$HOME/.anyenv"
    export PATH="$ANYENV_ROOT/bin:$PATH"
    if command -v anyenv 1>/dev/null 2>&1
    then
        eval "$(anyenv init -)"
    fi
fi

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
