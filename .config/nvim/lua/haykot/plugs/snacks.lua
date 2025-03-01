return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    terminal = {
      win = {
        position = "float",
        backdrop = false,
        height = 0.9,
        width = 0.9,
        border = "rounded",
      },
      auto_close = true,
    },
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
    input = { enabled = true },
    bigfile = { enabled = true },
    quickfile = { enabled = true },
    notifier = { enabled = false },
    statuscolumn = { enabled = false },
    words = { enabled = false },
    lazygit = {
      configure = true,
    },
    picker = {
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
          auto_close = true,
          layout = { preset = "vertical", preview = false },
        },
      },
      layout = {
        layout = {
          backdrop = false,
        },
      },
      formatters = {
        file = {
          truncate = 70,
          filename_first = true,
        },
      },
      win = {
        input = {
          keys = {
            ["<Esc>"] = { "close", mode = { "n", "i" } },
          },
        },
      },
    },
  },
  keys = {
    {
      "<leader>t",
      function()
        Snacks.terminal.toggle()
      end,
      desc = "resume last picker",
    },
    {
      "<leader>lt",
      function()
        -- regular files have empty string for buftype
        local is_file = vim.api.nvim_buf_get_option(0, "buftype") == ""
        if is_file then
          local filename = vim.api.nvim_buf_get_name(0)
          Snacks.terminal.toggle(nil, {
            cwd = vim.fs.dirname(filename),
          })
        end
      end,
      desc = "resume last picker",
    },
    {
      "<leader>ee",
      function()
        Snacks.explorer.reveal()
      end,
      desc = "toggle snacks explorer",
    },
    {
      "<leader>ff",
      function()
        Snacks.picker.files({
          cmd = "rg",
          hidden = true,
          ignored = false,
          args = { "--follow", "--glob", "!.git/*" },
        })
      end,
      desc = "Smart Find Files",
    },
    {
      "<leader>fl",
      function()
        Snacks.picker.resume()
      end,
      desc = "resume last picker",
    },
    {
      "<leader>fj",
      function()
        Snacks.picker.jumps()
      end,
      desc = "search just list",
    },
    {
      "<leader>fr",
      function()
        Snacks.picker.lsp_references()
      end,
      desc = "find lsp references",
    },
    {
      "<leader>fq",
      function()
        Snacks.picker.qflist()
      end,
      desc = "find quickfix",
    },
    {
      "<leader>fb",
      function()
        Snacks.picker.buffers()
      end,
      desc = "find buffer",
    },
    {
      "<leader>fib",
      function()
        Snacks.picker.lines()
      end,
      desc = "find in buffer",
    },
    {
      "<leader>fx",
      function()
        Snacks.picker.diagnostics()
      end,
      desc = "find trouble results",
    },
    {
      "<leader>fg",
      function()
        Snacks.picker.grep({ cmd = "rg", args = { "--hidden" } })
      end,
      desc = "find in files",
    },
    {
      "<leader>fc",
      function()
        Snacks.picker.git_status()
      end,
      desc = "find changed files",
    },
    {
      "<leader>fp",
      function()
        Snacks.picker.pickers()
      end,
      desc = "find changed files",
    },

    {
      "<leader>q",
      function()
        Snacks.bufdelete()
      end,
      desc = "Delete Buffer",
    },
    {
      "<leader>gg",
      function()
        Snacks.lazygit()
      end,
      desc = "Lazygit",
    },
    {
      "<leader>gb",
      function()
        Snacks.git.blame_line()
      end,
      desc = "Git Blame Line",
    },
    {
      "<leader>go",
      function()
        Snacks.gitbrowse.open({})
      end,
      desc = "open git remote",
    },
    {
      "<leader>gf",
      function()
        Snacks.lazygit.log_file()
      end,
      desc = "Lazygit Current File History",
    },
    {
      "<leader>gl",
      function()
        Snacks.lazygit.log()
      end,
      desc = "Lazygit Log (cwd)",
    },
    {
      "gd",
      function()
        Snacks.picker.lsp_definitions()
      end,
      desc = "Goto Definition",
    },
    {
      "gD",
      function()
        Snacks.picker.lsp_declarations()
      end,
      desc = "Goto Declaration",
    },
    {
      "gr",
      function()
        Snacks.picker.lsp_references()
      end,
      nowait = true,
      desc = "References",
    },
    {
      "gI",
      function()
        Snacks.picker.lsp_implementations()
      end,
      desc = "Goto Implementation",
    },
    {
      "gy",
      function()
        Snacks.picker.lsp_type_definitions()
      end,
      desc = "Goto T[y]pe Definition",
    },
    {
      "<leader>fs",
      function()
        Snacks.picker.lsp_symbols()
      end,
      desc = "LSP Symbols",
    },
    {
      "<leader>fws",
      function()
        Snacks.picker.lsp_workspace_symbols()
      end,
      desc = "LSP Workspace Symbols",
    },
  },
}
