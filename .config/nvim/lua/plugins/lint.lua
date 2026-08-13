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
      -- linter は別途インストールが必要
      -- 未インストールのものは util.lint 側で自動的に飛ばすため、
      -- 使う分だけ入れれば足りる
      --
      -- shell      brew install shellcheck
      -- zsh        追加インストール不要 (zsh -n による構文確認)
      -- yaml       brew install yamllint
      -- json       npm install -g jsonlint
      -- markdown   npm install -g markdownlint-cli
      -- lua        brew install luacheck
      -- php        brew install php          (php -l をそのまま使う)
      -- ruby       gem install rubocop
      -- python     brew install ruff
      -- javascript npm install -g eslint     (PATH から引くのでグローバル導入が前提)
      --
      -- 追加できる linter の一覧はこちらを参照する
      -- https://github.com/mfussenegger/nvim-lint#available-linters
      require("lint").linters_by_ft = {
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        -- shellcheck は zsh 非対応なので専用の linter を使う
        zsh = { "zsh" },
        yaml = { "yamllint" },
        json = { "jsonlint" },
        jsonc = { "jsonlint" },
        markdown = { "markdownlint" },
        lua = { "luacheck" },
        php = { "php" },
        ruby = { "rubocop" },
        python = { "ruff" },
        javascript = { "eslint" },
        javascriptreact = { "eslint" },
        typescript = { "eslint" },
        typescriptreact = { "eslint" },
        vue = { "eslint" },
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
