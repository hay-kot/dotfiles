local lsp = require("lsp-zero")
local cmp = require("cmp")

lsp.preset("recommended")
-- LSP Zero auto-completion
lsp.setup_nvim_cmp({
	sources = {
		--- These are the default sources for lsp-zero
		{ name = "path" },
		{ name = "nvim_lsp", keyword_length = 3 },
		{ name = "buffer", keyword_length = 3 },
		{ name = "luasnip", keyword_length = 2 },
	},
	mapping = lsp.defaults.cmp_mappings({
		["<CR>"] = cmp.mapping.confirm({
			-- documentation says this is important.
			-- I don't know why.
			behavior = cmp.ConfirmBehavior.Replace,
			select = false,
		}),
	}),
})

-- LSP Zero null-ls
local null_ls = require("null-ls")
local null_opts = lsp.build_options("null-ls", {})

null_ls.setup({
	debug = true,
	on_attach = null_opts.on_attach,
	sources = {
		null_ls.builtins.formatting.black,
		null_ls.builtins.formatting.prettier,
		null_ls.builtins.formatting.stylua,

		-- Go
		null_ls.builtins.formatting.gofumpt,
	},
})

-- Vim Diagnostics Setings (mostly care about virtual text)
vim.diagnostic.config({
	virtual_text = true,
	signs = true,
	update_in_insert = false,
	underline = true,
	severity_sort = false,
	float = true,
})

lsp.setup()
