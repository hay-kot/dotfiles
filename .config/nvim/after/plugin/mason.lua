local servers = {
	"pyright",
	"jsonls",
	"html",
	"gopls",
}

print("Loading Mason")

require("mason").setup({
	ui = {
		border = "none",
		icons = {
			package_installed = "◍",
			package_pending = "◍",
			package_uninstalled = "◍",
		},
	},
	log_level = vim.log.levels.INFO,
	max_concurrent_installers = 4,
})

require("mason-lspconfig").setup({
	ensure_installed = servers,
	automatic_installation = true,
})
