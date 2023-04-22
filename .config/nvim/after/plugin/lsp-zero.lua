local lsp = require("lsp-zero")
local copilot = require("copilot.suggestion")
lsp.preset("recommended")

lsp.on_attach(function(_, bufnr)
	lsp.default_keymaps({ buffer = bufnr })

	local map = function(m, lhs, rhs)
		local opts = { buffer = bufnr }
		vim.keymap.set(m, lhs, rhs, opts)
	end

  -- Keymap Overrides
  -- 
	map("n", "<leader>r", "<cmd>lua vim.lsp.buf.rename()<cr>")
  map("n", "gd", "<cmd>lua vim.lsp.buf.definition()<cr>")
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

lsp.setup_nvim_cmp({
	sources = {
		--- These are the default sources for lsp-zero
		{ name = "path" },
		{ name = "nvim_lsp", keyword_length = 3 },
		{ name = "buffer", keyword_length = 3 },
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
