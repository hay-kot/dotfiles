local km = require("haykot.keymaps")

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
  -- Go
  lspconfig.gopls.setup({
    on_attach = function(client)
      -- Lua function
      local function IfErr()
        local bpos = vim.fn.wordcount().cursor_bytes
        local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)

        -- Run the external command with "iferr" and capture the output
        local out = vim.fn.systemlist("iferr -pos " .. bpos, content)

        -- Check if there are any errors
        if #out == 1 then
          print("IfErr() -> no err found")
          return
        end

        local current_line, current_col = unpack(vim.api.nvim_win_get_cursor(0))

        -- Get the current line's indentation
        local current_indent = vim.fn.indent(current_line)

        -- Construct the indented multiline text
        local indented_text = {}
        for _, line in ipairs(out) do
          table.insert(indented_text, string.rep(" ", current_indent) .. line)
        end

        table.insert(indented_text, "")

        -- Move the cursor to the line below the current line
        vim.api.nvim_win_set_cursor(0, { current_line + 1, 0 })

        -- Insert the indented multiline text at the current cursor position
        vim.api.nvim_put(indented_text, "", false, true)

        -- Move the cursor to the end of the last line of the inserted text
        vim.api.nvim_win_set_cursor(0, { current_line + #out, current_col + #indented_text[#indented_text] })
      end

      km.nnoremap("<leader>er", IfErr, { desc = "Run iferr" })
    end,
  })

  --------------------------------------------
  -- Bash
  lspconfig.bashls.setup({
    filetypes = { "sh", "zsh" },
  })

  --------------------------------------------
  -- Html
  lspconfig.html.setup({
    init_options = {
      configurationSection = { "html", "css", "javascript" },
      embeddedLanguages = {
        css = true,
        javascript = true,
      },
      provideFormatter = false, -- fallback to null-ls/prettier
    },
    on_attach = function(_, bufnr)
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end,
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
    on_attach = function(client)
      -- Disable formatting
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
      -- interfere with github copilot
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
        { name = "buffer", keyword_length = 3 },
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

        -- Typos
        null_ls.builtins.diagnostics.typos,
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

    config_lsps(lsp)
  end,
}
