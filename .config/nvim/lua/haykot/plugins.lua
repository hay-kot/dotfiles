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

-- To use a local development version of diff-review, clone the repo to ~/dev/diff-review.
-- When that directory exists, lazy.nvim will load from it instead of the remote repo.
local local_path = vim.fn.expand("~/dev/diff-review")
local use_local = vim.loop.fs_stat(local_path) ~= nil

require("lazy").setup({
  -- Base Plugins
  "nvim-lua/plenary.nvim", -- Useful lua functions used by lots of plugins
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},

    config = function()
      vim.cmd([[colorscheme tokyonight-night]])
    end,
  },
  {
    "colonyops/diff-review",
    dir = use_local and local_path or nil,
    name = "diff-review.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("diff-review").setup()
    end,
  },
  {
    "norcalli/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup()
    end,
  },
  -- Auto Session Manager
  {
    priority = 100,
    "rmagatti/auto-session",
    cond = function()
      -- Don't load auto-session if disabled
      return vim.g.auto_session_enabled ~= false
    end,
    config = function()
      vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

      require("auto-session").setup({
        bypass_session_save_file_types = {
          "",
          "blank",
          "alpha",
          "NvimTree",
          "nofile",
          "dapui",
          "dap",
          "DiffReview",
        },
        log_level = "error",
        auto_session_suppress_dirs = { "~/", "~/code", "~/code/repos", "~/Downloads", "/" },
        pre_save_cmds = { "silent! DiffReviewClose" },
        pre_restore_cmds = {
          function()
            require("haykot.lib.globals").session_restored = true
          end,
        },
      })
    end,
  },

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

  -- Lsp Stuff
  -- require("haykot.plugs.cmp"),
  require("haykot.plugs.blink"),
  require("haykot.plugs.lsp"),
  require("haykot.plugs.null-ls"),

  require("haykot.plugs.dev-icons"),
  require("haykot.plugs.snacks"),

  -- UI Elements for Search and cmd
  -- Mostly used for the main command bar, not sure if there's anything else I use in this
  {
    "folke/noice.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    config = function()
      require("noice").setup({
        lsp = {
          hover = { enabled = false },
          signature = { enabled = false },
          -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = false,
            ["vim.lsp.util.stylize_markdown"] = false,
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
        icons = false, -- { breakpoint = "🧘", currentpos = "🏃" }, -- set to false to disable
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
        "<leader>gt",
        function()
          require("gitsigns").preview_hunk()
        end,
        desc = "git status",
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
