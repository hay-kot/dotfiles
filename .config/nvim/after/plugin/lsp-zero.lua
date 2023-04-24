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
  lsp.default_keymaps({ buffer = bufnr })

  km.nnoremap("gd", function()
    vim.lsp.buf.definition()
  end, { desc = "Go to definition" })

  km.nnoremap("K", function()
    vim.lsp.buf.hover()
  end, { desc = "Show hover information" })

  km.nnoremap("<leader>vws", function()
    vim.lsp.buf.workspace_symbol()
  end, { desc = "Search for symbols in workspace" })

  km.nnoremap("<leader>vd", function()
    vim.diagnostic.open_float()
  end, { desc = "Open diagnostic float" })

  km.nnoremap("[d", function()
    vim.diagnostic.goto_next()
  end, { desc = "Jump to next diagnostic" })

  km.nnoremap("]d", function()
    vim.diagnostic.goto_prev()
  end, { desc = "Jump to previous diagnostic" })

  km.nnoremap("<leader>vca", function()
    vim.lsp.buf.code_action()
  end, { desc = "Show code actions" })

  km.nnoremap("<leader>vrr", function()
    vim.lsp.buf.references()
  end, { desc = "Find references" })

  km.nnoremap("<leader>vrn", function()
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

null_ls.setup({
  debug = false,
  on_attach = null_opts.on_attach,
  sources = {
    null_ls.builtins.formatting.black,
    null_ls.builtins.formatting.prettier,
    null_ls.builtins.formatting.stylua,

    -- Go
    null_ls.builtins.formatting.gofumpt,
    null_ls.builtins.formatting.goimports,
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

--------------------------------------------
-- Specific LSP Configs
--------------------------------------------
require("lspconfig").yamlls.setup({
  settings = {
    yaml = {
      keyOrdering = false, -- Disabled Ordered Fields Linting
    },
  },
})

-- Fix Undefined global 'vim'
require("lspconfig").lua_ls.setup(lsp.nvim_lua_ls())
