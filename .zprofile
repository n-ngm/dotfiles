# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# additional PATH
export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"
export PATH="/opt/homebrew/opt/mysql@5.7/bin:$PATH"
export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"

export GOBIN=$HOME/bin
export PATH="$GOBIN:$PATH"

# mise
eval "$(mise activate zsh --shims)"

# PATH 重複を削除
export PATH=$(printf %s "$PATH" | awk -v RS=: -v ORS=: '!arr[$0]++')
