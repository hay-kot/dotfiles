local utils = require("haykot.lib.utils")

local ok = utils.guard_module({
  "mason",
  "mason-lspconfig",
})

if not ok then
  return
end

local servers = {
  "pyright",
  "jsonls",
  "html",
  "gopls",
}

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
