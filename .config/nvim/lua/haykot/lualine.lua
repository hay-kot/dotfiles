local status_ok, comment = pcall(require, "lualine")
if not status_ok then
  return
end

require("lualine").setup({
  options = {
    theme = "gruvbox",
  },
})
