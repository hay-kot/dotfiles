--------------------------------------------
-- Specific LSP Configs
--------------------------------------------
local function config_lsps(lsp)
  local lspconfig = require("lspconfig")

  lspconfig.yamlls.setup({
    settings = {
      yaml = {
        keyOrdering = false, -- Disabled Ordered Fields Linting
      },
    },
  })

  --------------------------------------------
  -- Javascript
  lspconfig.eslint.setup({
    settings = {
      packageManager = "pnpm",
    },
    on_attach = function(_, bufnr)
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        command = "EslintFixAll",
      })
    end,
  })

  -- Volar
  lspconfig.volar.setup({
    -- Disable formatting
    on_attach = function(client)
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end,
  })

  -- Fix Undefined global 'vim'
  lspconfig.lua_ls.setup(lsp.nvim_lua_ls())
end

return {
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
  config = function()
    local utils = require("haykot.lib.utils")

    local ok = utils.guard_module({
      "lsp-zero",
      "copilot.suggestion",
      "cmp",
      "null-ls",
      "lspconfig",
      "luasnip.loaders.from_vscode",
    })

    if not ok then
      return
    end

    local km = require("haykot.keymaps")

    local lsp = require("lsp-zero")
    local copilot = require("copilot.suggestion")

    lsp.preset("recommended")
    lsp.on_attach(function(_, bufnr)
      lsp.default_keymaps({
        buffer = bufnr,
        omit = { "gd" },
      })

      km.nnoremap("gd", function()
        require("telescope.builtin").lsp_definitions()
      end, { desc = "Go to definition", buffer = true })

      km.nnoremap("K", function()
        vim.lsp.buf.hover()
      end, { desc = "Show hover information" })

      km.nnoremap("<leader>lws", function()
        require("telescope.builtin").lsp_workspace_symbols()
      end, { desc = "Search for symbols in workspace", buffer = true })

      km.nnoremap("<leader>ld", function()
        vim.diagnostic.open_float()
      end, { desc = "Open diagnostic float" })

      km.nnoremap("[d", function()
        vim.diagnostic.goto_next()
      end, { desc = "Jump to next diagnostic" })

      km.nnoremap("]d", function()
        vim.diagnostic.goto_prev()
      end, { desc = "Jump to previous diagnostic" })

      km.nnoremap("<leader>lca", function()
        vim.lsp.buf.code_action()
      end, { desc = "Show code actions" })

      km.nnoremap("<leader>lfr", function()
        require("telescope.builtin").lsp_references()
      end, { desc = "Find references", buffer = true })

      km.nnoremap("<leader>fs", function()
        require("telescope.builtin").lsp_document_symbols()
      end, { desc = "Show document symbols" })

      km.nnoremap("<leader>lr", function()
        vim.lsp.buf.rename()
      end, { desc = "Rename symbol" })

      km.inoremap("<C-h>", function()
        vim.lsp.buf.signature_help()
      end, { desc = "Show signature help" })

      km.nnoremap("<leader>lf", "<cmd>lua vim.lsp.buf.format()<CR>", { desc = "format file" })
      -- command Format
      vim.cmd([[command! Fmt execute 'lua vim.lsp.buf.format()']])
    end)

    local cmp = require("cmp")
    cmp.setup({
      sources = {
        {
          name = "nvim_lsp",
          max_item_count = 100,
        },
      },
    })
    local cmp_mappings = lsp.defaults.cmp_mappings({
      -- Configure Ctrl-Space to trigger completion
      ["<C-Space>"] = cmp.mapping.complete(),
      -- Configure Ctrl-y to confirm completion
      ["<S-CR>"] = cmp.mapping.confirm({ select = true }),
      -- Configure tab to select the first item in the completion, but not
      -- interfer with github copilot
      --
      -- TODO: Change up/down to C-n/C-p
      ["<Tab>"] = cmp.mapping(function(fallback)
        if copilot.is_visible() then
          copilot.accept()
        elseif cmp.visible() then
          cmp.select_next_item()
        else
          fallback()
        end
      end, {
        "i",
        "s",
      }),
    })

    -- Reset CR to nil
    --
    -- Required or else it will drive you crazy
    cmp_mappings["<CR>"] = nil
    cmp_mappings["<C-m>"] = nil

    require("luasnip.loaders.from_vscode").lazy_load()

    lsp.setup_nvim_cmp({
      sources = {
        --- These are the default sources for lsp-zero
        { name = "path" },
        { name = "nvim_lsp" },
        { name = "nvim_lua" },
        { name = "buffer",  keyword_length = 3 },
        { name = "luasnip", keyword_length = 2 },
      },
      mapping = cmp_mappings,
    })

    -- LSP Zero null-ls
    local null_ls = require("null-ls")
    local null_opts = lsp.build_options("null-ls", {})

    local eslint_configs = {
      ".eslint.json",
      ".eslintrc.js",
      ".eslintrc",
      "./frontend/.eslint.json",
      "./frontend/.eslintrc.js",
      "./frontend/.eslintrc",
    }

    local prettier_configs = {
      ".prettierrc",
      ".prettierrc.js",
      ".prettierrc.json",
      "./frontend/.prettierrc",
      "./frontend/.prettierrc.js",
      "./frontend/.prettierrc.json",
    }

    null_ls.setup({
      debug = false,
      on_attach = null_opts.on_attach,
      sources = {
        null_ls.builtins.formatting.black,

        -- JavaScript
        null_ls.builtins.formatting.prettier.with({
          condition = function(null_utils)
            local has_eslint = null_utils.has_file(eslint_configs)
            local has_prettier = null_utils.has_file(prettier_configs)

            if has_prettier then
              return true
            elseif has_eslint then
              return false
            else
              return true
            end
          end,
        }),

        -- Lua
        null_ls.builtins.formatting.stylua,

        -- Go
        null_ls.builtins.formatting.gofumpt,
        null_ls.builtins.formatting.goimports,

        -- YAML, JSON, XML, CSV
        null_ls.builtins.formatting.yq,
      },
    })

    lsp.setup()

    -- Vim Diagnostics Setings (mostly care about virtual text)
    vim.diagnostic.config({
      virtual_text = true,
      signs = true,
      update_in_insert = false,
      underline = true,
      severity_sort = false,
      float = true,
    })

    config_lsps(lsp)
  end,
}