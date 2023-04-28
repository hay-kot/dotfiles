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
require("haykot.toggleterm")
require("haykot.lualine")
require("haykot.bufferline")
