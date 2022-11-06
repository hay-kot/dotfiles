local M = {}

M.project_files = function()
  local opts = {} -- define here if you want to define something
  local ok = pcall(require"telescope.builtin".git_files, {
    show_untracked = true,
  })
  if not ok then require"telescope.builtin".find_files({
    find_command = {"rg", "--files", "--hidden", "--follow", "--glob", "!.git/*"},
  }) end
end

M.dotfiles = function()
  require("telescope.builtin").git_files({
    show_untracked = true,
    prompt_title = "~ dotfiles ~",
    cwd = "~/.dotfiles",
  })
end

return M