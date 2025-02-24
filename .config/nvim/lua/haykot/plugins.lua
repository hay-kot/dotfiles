-- !Important: Leader key must be set before any plugins are loaded
local ensure_lazy = function()
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable", -- latest stable release
      lazypath,
    })
  end
  vim.opt.rtp:prepend(lazypath)
end

ensure_lazy()

require("lazy").setup({
  -- Base Plugins
  "nvim-lua/plenary.nvim", -- Useful lua functions used by lots of plugins
  {
    "sainnhe/gruvbox-material",
    enabled = true,
    priority = 1000,
    config = function()
      vim.o.background = "dark"
      vim.g.gruvbox_material_background = "hard"
      vim.cmd.colorscheme("gruvbox-material")

      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "bg", fg = "#d8db92" })
      vim.api.nvim_set_hl(0, "FloatBorder", { bg = "bg", fg = "#d8db92" })
    end,
  },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },
  {
    "norcalli/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup()
    end,
  },
  {
    enabled = false,
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup({
        disable_filetype = { "TelescopePrompt", "vim" },
      })
    end,
  },

  -- Auto Session Manager
  {
    priority = 100,
    "rmagatti/auto-session",
    config = function()
      vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

      require("auto-session").setup({
        bypass_session_save_file_types = { "", "blank", "alpha", "NvimTree", "nofile", "Trouble", "dapui", "dap" },
        log_level = "error",
        auto_session_suppress_dirs = { "~/", "~/code", "~/code/repos", "~/Downloads", "/" },
        pre_save_cmds = { "lua require('nvim-tree').setup()", "tabdo NvimTreeClose" },
        pre_restore_cmds = {
          function()
            require("haykot.lib.globals").session_restored = true
          end,
        },
      })
    end,
  },

  -- Which Key (Experimental, may remove)
  {
    "folke/which-key.nvim",
    config = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
      require("which-key").setup({
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      })
    end,
  },

  require("haykot.plugs.treesitter"),
  require("haykot.plugs.lualine"),
  require("haykot.plugs.mason"),
  require("haykot.plugs.lsp-zero"),
  require("haykot.plugs.trouble"),
  require("haykot.plugs.dev-icons"),
  require("haykot.plugs.comments"),

  -- UI Elements for Search and cmd
  -- Mostly used for the main command bar, not sure if there's anything else I use in this
  {
    "folke/noice.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    config = function()
      require("noice").setup({
        lsp = {
          hover = { enabled = false },
          signature = { enabled = true },
          -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = false,
          },
        },
        -- you can enable a preset for easier configuration
        presets = {
          bottom_search = false, -- use a classic bottom cmdline for search
          command_palette = true, -- position the cmdline and popupmenu together
          long_message_to_split = true, -- long messages will be sent to a split
          inc_rename = false, -- enables an input dialog for inc-rename.nvim
          lsp_doc_border = false, -- add a border to hover docs and signature help
        },
      })
    end,
  },

  {
    "ray-x/go.nvim",
    dependencies = { -- optional packages
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("go").setup({
        tag_options = "",
        tag_transform = "camelcase",
        lsp_semantic_highlights = false,
        textobjects = false,
        dap_debug_keymap = true,
        icons = false -- { breakpoint = "🧘", currentpos = "🏃" }, -- set to false to disable
      })

      -- disable sql colorizer
      -- https://github.com/ray-x/go.nvim/issues/360#issuecomment-2456754303
      vim.treesitter.query.set("go", "injections", "")
    end,
    event = { "CmdlineEnter" },
    ft = { "go", "gomod" },
    build = ':lua require("go.install").update_all_sync()', -- if you need to install/update all binaries
    keys = {
      {
        "<leader>gdb",
        function()
            vim.api.nvim_command("silent! GoDebug")
        end,
        desc = "Debug: Set Breakpoint",
      },
    },
  },

  -- Tabs
  {
    "akinsho/bufferline.nvim",
    version = "v4.*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },
  -- Git
  {
    "lewis6991/gitsigns.nvim",
    lazy = false,
    config = function()
      require("gitsigns").setup()
    end,
    keys = {
      {
        "<leader>gs",
        function()
          require("gitsigns").stage_hunk()
        end,
        desc = "stage hunk",
      },
      {
        "<leader>gus",
        function()
          require("gitsigns").undo_stage_hunk()
        end,
        desc = "undo stage hunk",
      },
      {
        "<leader>gp",
        function()
          require("gitsigns").preview_hunk()
        end,
        desc = "git status",
      },
      {
        "<leader>gb",
        function()
          require("gitsigns").toggle_current_line_blame()
        end,
        desc = "git toggle current line blame",
      },
    },
  },

  {
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
            Snacks.terminal.toggle(vim.fs.dirname(filename))
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
  },

  {
    "grafana/vim-alloy",
    lazy = true,
    ft = { "alloy" },
  },
  {
    "google/vim-jsonnet",
    lazy = true,
    ft = "jsonnet",
  },
  {
    "zbirenbaum/copilot-cmp",
    config = function()
      require("copilot_cmp").setup()
    end,
  },
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = { enabled = false },
        panel = { enabled = false },
      })
    end,
  },

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui", -- UI for dap
        dependencies = {
          "nvim-neotest/nvim-nio",
        },
        config = function()
          local dapui = require("dapui")
          local dap = require("dap")

          dapui.setup({
            icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
          })

          -- Change breakpoint icons
          vim.api.nvim_set_hl(0, "DapBreak", { fg = "#e51400" })
          vim.api.nvim_set_hl(0, "DapStop", { fg = "#ffcc00" })
          local breakpoint_icons = vim.g.have_nerd_font
              and {
                Breakpoint = "",
                BreakpointCondition = "",
                BreakpointRejected = "",
                LogPoint = "",
                Stopped = "",
              }
            or {
              Breakpoint = "●",
              BreakpointCondition = "⊜",
              BreakpointRejected = "⊘",
              LogPoint = "◆",
              Stopped = "⭔",
            }
          for type, icon in pairs(breakpoint_icons) do
            local tp = "Dap" .. type
            local hl = (type == "Stopped") and "DapStop" or "DapBreak"
            vim.fn.sign_define(tp, { text = icon, texthl = hl })
          end

          local onend = function()
            dapui.close()

            -- Need to terminate the session to drop keybindings set by
            vim.api.nvim_command("silent! GoDebug -s")
          end

          dap.listeners.after.event_initialized["dapui_config"] = dapui.open
          dap.listeners.before.event_terminated["dapui_config"] = onend
          dap.listeners.before.event_exited["dapui_config"] = onend
        end,
      },
      "theHamsta/nvim-dap-virtual-text", -- Virtual text support
    },
    config = function()
      require("nvim-dap-virtual-text").setup({
        show_stop_reason = true,
        commented = false,
      })
    end,
    keys = {
      {
        "<leader>pt",
        function()
          require("dapui").toggle()
        end,
      },
      {
        "<leader>B",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Debug: Set Breakpoint",
      },
    },
  },
})
