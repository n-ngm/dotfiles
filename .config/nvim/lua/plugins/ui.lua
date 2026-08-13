return {
  -- colorscheme
  {
    "jtai/vim-womprat",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("womprat")
    end,
  },

  -- ステータスライン (vim-airline / vim-airline-themes から移行)
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
        -- Nerd Font に依存しない見た目にする
        icons_enabled = false,
        section_separators = "",
        component_separators = "|",
        globalstatus = true,
      },
      -- 旧 airline の layout ([c] と [y, error, warning]) にそろえる
      sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {},
        lualine_y = { "encoding", "fileformat", "diagnostics" },
        lualine_z = {},
      },
      inactive_sections = {
        lualine_c = { { "filename", path = 1 } },
      },
      -- 旧 airline の tabline 相当
      tabline = {
        lualine_a = { { "buffers", mode = 2, use_mode_colors = true } },
      },
    },
  },
}
