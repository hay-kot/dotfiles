require("haykot.keymaps")
require("haykot.options")

-- If we're running on an infrastructure server, I don't care about the rest of
-- the config, I just want my options and keymaps.
local infra_server = os.getenv("INFRA_SERVER")
if infra_server == "true" then
  return
end

require("haykot.plugins")
require("haykot.theme")
require("haykot.treesitter")
require("haykot.toggleterm")
require("haykot.comment")
require("haykot.lualine")
require("haykot.bufferline")
require("haykot.nvim-tree")
