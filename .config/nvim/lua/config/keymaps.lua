-- 旧 .vimrc の map 系を移植したもの
-- プラグインに依存するキーマップは lua/plugins/ 側の keys で定義する
local map = vim.keymap.set

-- 折り返し行も表示行単位で移動する
map({ "n", "v", "o" }, "j", "gj")
map({ "n", "v", "o" }, "k", "gk")
map({ "n", "v", "o" }, "<Down>", "gj")
map({ "n", "v", "o" }, "<Up>", "gk")

-- カーソル下の単語を検索してもその場に留まる
map("n", "*", "*N")

-- バッファ操作
map("n", "<C-p>", "<Cmd>bprevious<CR>", { desc = "前のバッファ" })
map("n", "<C-n>", "<Cmd>bnext<CR>", { desc = "次のバッファ" })
map(
  "n",
  "<Leader>d",
  "<Cmd>bprevious<Bar>split<Bar>bnext<Bar>bdelete<Bar>bnext<CR>",
  { desc = "ウィンドウ分割を保ったままバッファを閉じる" }
)

-- 削除でレジスタを汚さない
map("n", "x", '"_x')
map("n", "D", '"_D')
map("n", "s", '"_s')

-- 選択範囲を上下に動かす
map("x", "J", ":m '>+1<CR>gv=gv", { silent = true })
map("x", "K", ":m '<-2<CR>gv=gv", { silent = true })

-- 選択範囲のヤンクはシステムクリップボードへ
map("x", "y", '"+y')

-- タグジャンプは候補が複数あれば一覧を出す
map("n", "<C-]>", "g<C-]>")
map("i", "<C-]>", "<Esc>g<C-]>")

-- ターミナル
map("t", "<Esc>", [[<C-\><C-n>]], { desc = "ターミナルを normal モードへ" })
