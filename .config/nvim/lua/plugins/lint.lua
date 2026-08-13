return {
  -- 静的解析 (syntastic から移行)
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
    keys = {
      -- 旧 <Leader>sc (SyntasticCheck) の置き換え
      {
        "<Leader>sc",
        function()
          require("util.lint").run()
        end,
        desc = "静的解析を実行",
      },
    },
    config = function()
      require("lint").linters_by_ft = {
        php = { "php" },
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        zsh = { "shellcheck" },
        yaml = { "yamllint" },
        markdown = { "markdownlint" },
        lua = { "luacheck" },
        javascript = { "eslint" },
        typescript = { "eslint" },
      }

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("myrc_lint", { clear = true }),
        callback = function()
          require("util.lint").run()
        end,
      })

      vim.diagnostic.config({
        signs = true,
        underline = true,
        severity_sort = true,
        virtual_text = { spacing = 2, prefix = "|" },
      })
    end,
  },
}
