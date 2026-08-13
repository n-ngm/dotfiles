return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    -- auto_start を効かせるため起動直後に読み込む
    event = "VeryLazy",
    keys = {
      { "<Leader>ac", "<Cmd>ClaudeCode<CR>", desc = "Claude Code の開閉" },
      { "<Leader>af", "<Cmd>ClaudeCodeFocus<CR>", desc = "Claude Code にフォーカス" },
      { "<Leader>as", "<Cmd>ClaudeCodeSend<CR>", mode = "v", desc = "選択範囲を Claude Code へ送る" },
    },
    opts = {
      auto_start = true,
      terminal = {
        split_side = "right",
        split_width_percentage = 0.30,
        provider = "native",
      },
      diff_opts = {
        auto_close_on_accept = true,
        vertical_split = true,
      },
    },
  },

  {
    "folke/snacks.nvim",
    lazy = true,
    opts = {},
  },
}
