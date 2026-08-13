-- Neovim 設定のエントリポイント
-- leader は lazy.nvim の読み込みより先に定義する必要がある
vim.g.mapleader = ","
vim.g.maplocalleader = ","

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
