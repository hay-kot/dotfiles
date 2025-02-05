local km = require("haykot.keymaps")

return {
  "VonHeikemen/lsp-zero.nvim",
  branch = "v3.x",
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
    {
      "L3MON4D3/LuaSnip",
      version = "v2.*",
      config = function()
        -- log to local file
        ls = require("luasnip")
        ls.log.set_loglevel("debug")

        -- Map "Ctrl + p" (in insert mode)
        -- to expand snippet and jump through fields.
        vim.api.nvim_set_keymap(
          "i",
          "<Tab>",
          "luasnip#expand_or_jumpable() ? '<Plug>luasnip-expand-or-jump' : '<Tab>'",
          { expr = true, silent = true }
        )
        vim.api.nvim_set_keymap("i", "<S-Tab>", "<cmd>lua require'luasnip'.jump(-1)<CR>", { silent = true })
        vim.api.nvim_set_keymap("s", "<Tab>", "<cmd>lua require('luasnip').jump(1)<CR>", { silent = true })
        vim.api.nvim_set_keymap("s", "<S-Tab>", "<cmd>lua require('luasnip').jump(-1)<CR>", { silent = true })

        require("luasnip.loaders.from_vscode").lazy_load({
          exclude = { "go" },
        })

        require("luasnip.loaders.from_vscode").lazy_load({
          paths = {
            "~/.config/nvim/lua/haykot/plugs/snips",
          },
        })
      end,
      lazy = false,
      dependencies = {
        { "rafamadriz/friendly-snippets" },
      },
    },

    -- Null LS (Optional)
    { "nvimtools/none-ls.nvim" },
  },
  config = function()
    local lsp = require("lsp-zero")

    lsp.preset("recommended")
    lsp.on_attach(function(_, bufnr)
      lsp.default_keymaps({
        buffer = bufnr,
        omit = { "gd" },
      })

      km.nnoremap("gd", function()
        require("telescope.builtin").lsp_definitions()
      end, { desc = "Go to definition", buffer = true })

      km.nnoremap("le", function()
        vim.diagnostic.goto_next()
      end, { desc = "Go to next diagnostic", buffer = true })

      km.nnoremap("lE", function()
        vim.diagnostic.goto_prev()
      end, { desc = "Go to previous diagnostic", buffer = true })

      km.nnoremap("K", function()
        vim.lsp.buf.hover()
      end, { desc = "Show hover information" })

      km.nnoremap("<leader>lws", function()
        require("telescope.builtin").lsp_workspace_symbols()
      end, { desc = "Search for symbols in workspace", buffer = true })

      km.nnoremap("<leader>lx", function()
        vim.diagnostic.open_float()
      end, { desc = "Open diagnostic float" })

      km.nnoremap("[d", function()
        vim.diagnostic.goto_next()
      end, { desc = "Jump to next diagnostic" })

      km.nnoremap("]d", function()
        vim.diagnostic.goto_prev()
      end, { desc = "Jump to previous diagnostic" })

      km.vnoremap("ca", function()
        vim.lsp.buf.code_action()
      end, { desc = "Show code actions" })

      km.nnoremap("<leader>lca", function()
        vim.lsp.buf.code_action()
      end, { desc = "Show code actions" })

      km.nnoremap("<leader>fs", function()
        require("telescope.builtin").lsp_document_symbols()
      end, { desc = "Show document symbols" })

      km.nnoremap("<leader>lr", function()
        vim.lsp.buf.rename()
      end, { desc = "Rename symbol" })

      km.inoremap("<C-h>", function()
        vim.lsp.buf.signature_help()
      end, { desc = "Show signature help" })

      km.nnoremap("<leader>lf", "<cmd>lua vim.lsp.buf.format({async=true})<CR>", { desc = "format file" })
      -- command Format
      vim.cmd([[command! Fmt execute 'lua vim.lsp.buf.format()']])
    end)

    local cmp = require("cmp")
    local cmp_format = lsp.cmp_format()
    local cmp_action = require("lsp-zero").cmp_action()

    cmp.setup({
      preselect = "none",
      formatting = cmp_format,
      mapping = cmp.mapping.preset.insert({
        -- Required or else it will drive you crazy
        ["<CR>"] = nil,
        ["<C-m>"] = nil,
        -- scroll up and down the documentation window
        ["<C-u>"] = cmp.mapping.scroll_docs(-4),
        ["<C-d>"] = cmp.mapping.scroll_docs(4),
        -- Configure Ctrl-Space to trigger completion
        ["<C-Space>"] = cmp.mapping.complete(),
        -- Configure Ctrl-y to confirm completion
        ["<S-CR>"] = cmp.mapping.confirm({ select = true }),
        -- Configure tab to select the first item in the completion, but not
        -- interfere with github copilot
        ["<Tab>"] = cmp_action.luasnip_supertab(),
        ["<S-Tab>"] = cmp_action.luasnip_shift_supertab(),
      }),
      sources = {
        { name = "nvim_lsp", max_item_count = 100 },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
      },
      snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)
        end,
      },
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

        -- Sql Formatter
        null_ls.builtins.formatting.sql_formatter.with({ command = { "sleek" } }),
      },
    })

    lsp.setup()

    -- Vim Diagnostics Settings (mostly care about virtual text)
    vim.diagnostic.config({
      virtual_text = true,
      signs = true,
      update_in_insert = false,
      underline = true,
      severity_sort = false,
      float = true,
    })
  end,
}
