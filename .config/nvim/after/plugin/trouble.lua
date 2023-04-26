local ok, _ = pcall(require, "trouble")
if not ok then
	return
end

local km = require("haykot.keymaps")

km.nnoremap("<leader>xx", ":TroubleToggle<CR>")
km.nnoremap("<leader>xw", ":TroubleToggle workspace_diagnostics<CR>")
km.nnoremap("<leader>xd", ":TroubleToggle document_diagnostics<CR>")
