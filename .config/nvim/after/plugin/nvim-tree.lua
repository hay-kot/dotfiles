local status_ok, nvim_tree = pcall(require, "nvim-tree")
if not status_ok then
	return
end

local km = require("haykot.keymaps")
km.nnoremap("<leader>ee", ":NvimTreeToggle<cr>") -- git files or all files
