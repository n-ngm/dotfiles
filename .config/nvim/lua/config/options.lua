-- 旧 .vimrc の set 系を移植したもの
local opt = vim.opt

-- encoding
-- Neovim の内部エンコーディングは常に utf-8 なので encoding は設定しない
opt.fileencodings = { "utf-8", "iso-2022-jp", "cp932", "sjis", "euc-jp" }
opt.fileformats = { "unix", "dos", "mac" }

-- cursor
opt.backspace = { "eol", "indent", "start" }
opt.wildmode = "list:longest"
opt.nrformats = ""

-- indent
opt.shiftwidth = 4
opt.tabstop = 4
opt.expandtab = true
opt.smarttab = true
opt.autoindent = true
opt.smartindent = true

-- buffer
opt.backup = false
opt.swapfile = false
opt.hidden = true
opt.splitbelow = true
opt.splitright = true

-- appearance
opt.background = "dark"
opt.number = true
opt.showmatch = true
opt.ambiwidth = "double"
opt.list = true
opt.listchars = {
  tab = "> ",
  trail = "-",
  nbsp = "%",
  extends = ">",
  precedes = "<",
}

-- search
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.wrapscan = false

-- spell
-- 綴り確認は spelunker.vim に任せるため本体の spell は無効にする
opt.spell = false
