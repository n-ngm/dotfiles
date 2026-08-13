-- 旧 .vimrc の autocmd と独自ハイライトを移植したもの
local function augroup(name)
  return vim.api.nvim_create_augroup("myrc_" .. name, { clear = true })
end

-- 独自ハイライト
-- colorscheme を読み込むと定義が消えるため、都度貼り直す
local function apply_highlights()
  vim.api.nvim_set_hl(0, "ZenkakuSpace", {
    cterm = { underline = true },
    ctermfg = "LightBlue",
    bg = "#666666",
  })
  vim.api.nvim_set_hl(0, "SpelunkerSpellBad", {
    cterm = { underline = true },
    ctermfg = 160,
    underline = true,
    fg = "#9e9e9e",
  })
  vim.api.nvim_set_hl(0, "SpelunkerComplexOrCompoundWord", {
    cterm = { underline = true },
    underline = true,
  })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup("highlights"),
  callback = apply_highlights,
})
apply_highlights()

-- 全角スペースを可視化する
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, {
  group = augroup("zenkaku_space"),
  callback = function()
    if vim.w.zenkaku_space_match then
      return
    end
    vim.w.zenkaku_space_match = vim.fn.matchadd("ZenkakuSpace", "　")
  end,
})

-- 保存時に .tags を更新する
-- 既に .tags があるディレクトリでのみ動く。universal-ctags が必要
vim.api.nvim_create_autocmd("BufWritePost", {
  group = augroup("ctags"),
  callback = function()
    if vim.fn.executable("ctags") == 0 then
      return
    end
    local tags_path = vim.fn.findfile(".tags", ".;")
    if tags_path == "" then
      return
    end
    vim.system({
      "ctags",
      "-R",
      "--languages=php",
      "--php-kinds=cdfin",
      "-f",
      ".tags",
    }, { cwd = vim.fn.fnamemodify(tags_path, ":p:h") })
  end,
})

-- ターミナルでは ambiwidth を single にする
-- Claude Code の罫線文字が崩れるのを防ぐため
vim.api.nvim_create_autocmd("TermOpen", {
  group = augroup("term"),
  callback = function()
    vim.opt_local.ambiwidth = "single"
  end,
})
