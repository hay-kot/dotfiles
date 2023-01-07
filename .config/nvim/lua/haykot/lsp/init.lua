local status_ok, _ = pcall(require, "lspconfig")
if not status_ok then
  return
end

require("haykot.lsp.mason")
require("haykot.lsp.handlers").setup()
require("haykot.lsp.null-is")
