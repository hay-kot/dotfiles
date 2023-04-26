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

-- session_restored synchronizes the behavior of the auto-session plugin
-- and the nvim-tree plugin. The auto-session plugin will restore the
-- previous session on startup, but the nvim-tree plugin will open the
-- file explorer on startup. This variable is used to prevent the
-- nvim-tree plugin from opening the file explorer on startup if a
-- session is restored.
local session_restored = false

require("lazy").setup({
  -- Base Plugins
  "nvim-lua/popup.nvim",  -- An implementation of the Popup API from vim in Neovim
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
        pre_save_cmds = { "lua require'nvim-tree'.setup()", "tabdo NvimTreeClose" },
        pre_restore_cmds = {
          function()
            session_restored = true
          end,
        },
      })
    end,
  },

  {
    priority = 99,
    lazy = false,
    "nvim-tree/nvim-tree.lua",
    tag = "nightly", -- optional, updated every week. (see issue #1193)
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local function open_nvim_tree()
        if session_restored then
          return
        end
        require("nvim-tree.api").tree.open()
      end

      vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })
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

  -- Improve Vim UI
  -- Mostly used for code action menu/select, but had some other nice
  -- UI improvements as well
  {
    "stevearc/dressing.nvim",
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
          bottom_search = false,   -- use a classic bottom cmdline for search
          command_palette = true,  -- position the cmdline and popupmenu together
          long_message_to_split = true, -- long messages will be sent to a split
          inc_rename = false,      -- enables an input dialog for inc-rename.nvim
          lsp_doc_border = false,  -- add a border to hover docs and signature help
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
  -- LSP Zero
  {
    "VonHeikemen/lsp-zero.nvim",
    dependencies = {
      -- LSP Support
      { "neovim/nvim-lspconfig" },
      { "williamboman/mason.nvim" },
      { "williamboman/mason-lspconfig.nvim" },

      -- Autocompletion
      { "hrsh7th/nvim-cmp" },
      { "hrsh7th/cmp-buffer" },
      { "hrsh7th/cmp-path" },
      { "saadparwaiz1/cmp_luasnip" },
      { "hrsh7th/cmp-nvim-lsp" },
      { "hrsh7th/cmp-nvim-lua" },

      -- Snippets
      { "L3MON4D3/LuaSnip" },
      -- Snippet Collection (Optional)
      { "rafamadriz/friendly-snippets" },

      -- Null LS (Optional)
      { "jose-elias-alvarez/null-ls.nvim" },
    },
  },

  -- Trouble LSP Diagnostics
  {
    "folke/trouble.nvim",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("trouble").setup({})
    end,
  },

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

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
  },

  "p00f/nvim-ts-rainbow",

  -- Git
  "airblade/vim-gitgutter", -- Shows a git diff in the gutter (sign column)

  -- Navigation
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.0", -- Fuzzy finder
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    enabled = function()
      -- Don't run fzf native on windows
      return vim.fn.has("win32") == 0
    end,
  },

  -- Pretty Things

  -- Comments
  "numToStr/Comment.nvim",
  "JoosepAlviste/nvim-ts-context-commentstring",
})
