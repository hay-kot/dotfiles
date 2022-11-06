local ok, harpoon = pcall(require, "harpoon")
if not ok then
  return
end

local km = require("haykot.keymaps")
km.nnoremap("<leader>jq", function() require("harpoon.ui").nav_file(1) end)
km.nnoremap("<leader>jw", function() require("harpoon.ui").nav_file(2) end)
km.nnoremap("<leader>je", function() require("harpoon.ui").nav_file(3) end)
km.nnoremap("<leader>jr", function() require("harpoon.ui").nav_file(4) end)
km.nnoremap("<leader>hh", function() require("harpoon.ui").toggle_quick_menu() end)
km.nnoremap("<leader>a", function() require("harpoon.mark").add_file() end)