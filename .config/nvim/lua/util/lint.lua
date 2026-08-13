-- nvim-lint の実行ヘルパー
-- キーマップからも autocmd からも呼ぶため独立したモジュールにしている
local M = {}

-- 実行ファイルが入っていない linter は黙って飛ばす
-- syntastic と違い、未導入でもエラーを出さないようにするため
local function available(names)
  local lint = require("lint")
  return vim.tbl_filter(function(name)
    local linter = lint.linters[name]
    local cmd = type(linter) == "table" and linter.cmd or name
    if type(cmd) == "function" then
      cmd = cmd()
    end
    return vim.fn.executable(cmd) == 1
  end, names)
end

function M.run()
  local lint = require("lint")
  local names = available(lint.linters_by_ft[vim.bo.filetype] or {})
  if #names > 0 then
    lint.try_lint(names)
  end
end

return M
