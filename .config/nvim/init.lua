require("haykot.keymaps")
require("haykot.options")

local infra_server = os.getenv("INFRA_SERVER")
if infra_server == "true" then
	return
end

require("haykot.plugins")
require("haykot.cmp")
require("haykot.theme")
require("haykot.lsp")
require("haykot.treesitter")
require("haykot.toggleterm")
require("haykot.comment")
require("haykot.lualine")
require("haykot.bufferline")
require("haykot.nvim-tree")
