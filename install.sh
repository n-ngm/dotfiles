#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0);pwd)
OS="$(uname -s)"

cd $HOME
ln -snf $SCRIPT_DIR/.gitconfig .gitconfig
ln -snf $SCRIPT_DIR/.tmux.conf .tmux.conf
ln -snf $SCRIPT_DIR/.zshrc     .zshrc
ln -snf $SCRIPT_DIR/.alias     .alias
# Brewfile (OS-specific)
if [ "$OS" = "Darwin" ]; then
  ln -snf $SCRIPT_DIR/.Brewfile.mac .Brewfile
elif [ "$OS" = "Linux" ]; then
  ln -snf $SCRIPT_DIR/.Brewfile.ubuntu .Brewfile
fi
mkdir -p .claude
ln -snf $SCRIPT_DIR/.claude/commands  .claude/commands
ln -snf $SCRIPT_DIR/.claude/scripts   .claude/scripts
ln -snf $SCRIPT_DIR/.claude/CLAUDE.md .claude/CLAUDE.md

# macOS only
if [ "$OS" = "Darwin" ]; then
  ln -snf $SCRIPT_DIR/.zprofile  .zprofile
fi

cd $HOME
mkdir -p .config/sheldon
ln -snf $SCRIPT_DIR/.config/sheldon/plugins.toml .config/sheldon/plugins.toml

# nvim (lazy-lock.json も dotfiles 側に置くためディレクトリごとリンクする)
cd $HOME
mkdir -p .config
if [ -e .config/nvim ] && [ ! -L .config/nvim ]; then
  mv .config/nvim .config/nvim.bak
  echo "既存の .config/nvim を .config/nvim.bak へ退避しました"
fi
ln -snf $SCRIPT_DIR/.config/nvim .config/nvim

cd $HOME
mkdir -p .local/bin
cd .local/bin
ln -snf $SCRIPT_DIR/bin/ai-commit-message ai-commit-message
ln -snf $SCRIPT_DIR/bin/ai-pull-request ai-pull-request
ln -snf $SCRIPT_DIR/bin/termcolor.pl termcolor.pl
ln -snf $SCRIPT_DIR/bin/recreate-pull-request recreate-pull-request
ln -snf $SCRIPT_DIR/bin/tmux-pane-border tmux-pane-border
