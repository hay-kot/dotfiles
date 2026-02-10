-- Disable auto-session when using -c commands (must be before plugins load)
for _, arg in ipairs(vim.v.argv) do
  if arg == "-c" or arg == "+c" then
    vim.g.auto_session_enabled = false
    break
  end
end

require("haykot.keymaps")
require("haykot.usercommands")
require("haykot.options")

-- If we're running on an infrastructure server, I don't care about the rest of
-- the config, I just want my options and keymaps.
local infra_server = os.getenv("INFRA_SERVER")
if infra_server == "true" then
  return
end

require("haykot.plugins")
require("haykot.project-setup").setup()
require("haykot.bufferline")
