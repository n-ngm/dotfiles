require("claudecode").setup({
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
})

-- terminal buffer で ambiwidth=single にする (Claude Code の罫線文字の表示崩れ防止)
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.ambiwidth = "single"
  end,
})

-- keymaps
vim.keymap.set("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude Code" })
vim.keymap.set("n", "<leader>af", "<cmd>ClaudeCodeFocus<cr>", { desc = "Focus Claude Code" })
vim.keymap.set("v", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "Send to Claude Code" })
