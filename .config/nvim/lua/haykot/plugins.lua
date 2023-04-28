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
  "nvim-lua/popup.nvim",   -- An implementation of the Popup API from vim in Neovim
  "nvim-lua/plenary.nvim", -- Useful lua functions used ny lots of plugins
  -- "simrat39/rust-tools.nvim",
  "akinsho/toggleterm.nvim",

  {
    priority = 101,
    "morhetz/gruvbox",
  },

  -- Auto Session Manager
  {
    priority = 100,
    "rmagatti/auto-session",
    config = function()
      require("auto-session").setup({
        bypass_session_save_file_types = { "", "blank", "alpha", "NvimTree", "nofile", "Trouble" },
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

  require("haykot.plugs.nvim-tree"),

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
  require("haykot.plugs.telescope"),
  require("haykot.plugs.mason"),
  require("haykot.plugs.lsp-zero"),
  require("haykot.plugs.trouble"),
  require("haykot.plugs.dev-icons"),

  -- Improve Vim UI
  -- Mostly used for code action menu/select, but had some other nice
  -- UI improvements as well
  {
    "stevearc/dressing.nvim",
    config = function()
      require("dressing").setup({
        input = { enabled = false },
      })
    end,
  },

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
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
        },
        -- you can enable a preset for easier configuration
        presets = {
          bottom_search = false,        -- use a classic bottom cmdline for search
          command_palette = true,       -- position the cmdline and popupmenu together
          long_message_to_split = true, -- long messages will be sent to a split
          inc_rename = false,           -- enables an input dialog for inc-rename.nvim
          lsp_doc_border = false,       -- add a border to hover docs and signature help
        },
      })
    end,
  },

  {
    "zbirenbaum/copilot.lua",
    config = function()
      require("copilot").setup({
        enabled = true,
        suggestion = {
          enabled = true,
          auto_trigger = true,
          debounce = 75,
          keymap = {
            accept = "<M-l>",
            accept_word = false,
            accept_line = false,
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
        filetypes = {
          yaml = false,
          markdown = false,
          help = false,
          gitcommit = false,
          gitrebase = false,
          hgcommit = false,
          svn = false,
          cvs = false,
          ["*"] = true,
        },
      })
    end,
  },

  -- Vim Test
  "hay-kot/vim-test",

  -- Tabs
  {
    "akinsho/bufferline.nvim",
    version = "v3.*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },

  -- Status Line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },

  "p00f/nvim-ts-rainbow",

  -- Git
  "airblade/vim-gitgutter", -- Shows a git diff in the gutter (sign column)

  -- Comments
  "numToStr/Comment.nvim",
  "JoosepAlviste/nvim-ts-context-commentstring",
})
