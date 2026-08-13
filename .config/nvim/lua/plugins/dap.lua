return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
      },
    },
    -- 旧 vdebug のキー割り当てを引き継いでいる
    keys = {
      {
        "<F5>",
        function()
          require("dap").continue()
        end,
        desc = "デバッグ開始 / 続行",
      },
      {
        "<F2>",
        function()
          require("dap").step_over()
        end,
        desc = "ステップオーバー",
      },
      {
        "<F3>",
        function()
          require("dap").step_into()
        end,
        desc = "ステップイン",
      },
      {
        "<F4>",
        function()
          require("dap").step_out()
        end,
        desc = "ステップアウト",
      },
      {
        "<F6>",
        function()
          require("dap").terminate()
        end,
        desc = "デバッグ終了",
      },
      {
        "<F9>",
        function()
          require("dap").run_to_cursor()
        end,
        desc = "カーソル行まで実行",
      },
      {
        "<F10>",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "ブレークポイントの切り替え",
      },
      {
        "<F11>",
        function()
          require("dapui").toggle()
        end,
        desc = "デバッグ UI の開閉",
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()

      dap.listeners.before.attach.dapui = dapui.open
      dap.listeners.before.launch.dapui = dapui.open
      dap.listeners.before.event_terminated.dapui = dapui.close
      dap.listeners.before.event_exited.dapui = dapui.close

      -- PHP (Xdebug)
      -- ポートとパスマッピングは旧 .vimrc の vdebug 設定から引き継いだもの
      -- 実際に使うには vscode-php-debug の配置が必要:
      --   git clone https://github.com/xdebug/vscode-php-debug ~/.local/share/php-debug
      --   cd ~/.local/share/php-debug && npm install && npm run build
      dap.adapters.php = {
        type = "executable",
        command = "node",
        args = { vim.fn.expand("~/.local/share/php-debug/out/phpDebug.js") },
      }

      dap.configurations.php = {
        {
          type = "php",
          request = "launch",
          name = "Xdebug を待ち受ける",
          port = 9003,
          pathMappings = {
            ["/app"] = vim.fn.expand("~/Projects/HotStartup/peraichi"),
          },
        },
      }
    end,
  },
}
