return {
  -- ファイル検索
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    keys = {
      { "<Leader>ff", "<Cmd>Telescope find_files<CR>", desc = "ファイル検索" },
      { "<Leader>fg", "<Cmd>Telescope live_grep<CR>", desc = "文字列検索" },
      { "<Leader>fb", "<Cmd>Telescope buffers<CR>", desc = "バッファ一覧" },
      { "<Leader>fh", "<Cmd>Telescope help_tags<CR>", desc = "ヘルプ検索" },
    },
    opts = {},
  },

  -- git の変更行表示 (vim-gitgutter から移行)
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "-" },
        changedelete = { text = "~" },
      },
    },
  },

  -- git 操作
  {
    "tpope/vim-fugitive",
    cmd = { "G", "Git", "Gdiffsplit", "Gread", "Gwrite", "Glog", "Gclog" },
  },

  -- 綴り確認
  {
    "kamykn/spelunker.vim",
    event = { "BufReadPost", "BufNewFile" },
    init = function()
      vim.g.enable_spelunker_vim = 1
    end,
  },

  -- カラーコードのプレビュー
  {
    "gorodinskiy/vim-coloresque",
    ft = {
      "css",
      "scss",
      "sass",
      "less",
      "stylus",
      "html",
      "vue",
      "javascript",
      "typescript",
    },
  },

  -- タグ一覧
  {
    "preservim/tagbar",
    cmd = "TagbarToggle",
    keys = {
      { "<F8>", "<Cmd>TagbarToggle<CR>", desc = "タグ一覧の開閉" },
    },
  },

  -- 電卓
  {
    "theniceboy/vim-calc",
    keys = {
      {
        "<Leader>ca",
        function()
          vim.fn.Calc()
        end,
        desc = "電卓",
      },
    },
  },

  -- markdown プレビュー
  {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown", "pandoc.markdown", "rmd" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
  },
}
