local ok, telescope = pcall(require, "telescope")
if not ok then
  return
end

-- close on escape
local actions = require("telescope.actions")

local telescope_config = require("telescope.config")

-- unpack depreciated in lua 5.2
local vimgrep_args = { unpack(telescope_config.values.vimgrep_arguments) }

-- Searches hidden directories and files by default
-- with live_grep
table.insert(vimgrep_args, "--hidden")
table.insert(vimgrep_args, "--glob")
table.insert(vimgrep_args, "!.git/*")

telescope.setup({
  defaults = {
    sorting_strategy = "ascending",
    vimgrep_arguments = vimgrep_args,
    layout_config = {
      prompt_position = "top",
    },
    prompt_prefix = " ",
    mappings = {
      i = {
        ["<esc>"] = actions.close,
      },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true,                -- false will only do exact matching
      override_generic_sorter = true, -- override the generic sorter
      override_file_sorter = true, -- override the file sorter
      case_mode = "smart_case",    -- or "ignore_case" or "respect_case"
      -- the default case_mode is "smart_case"
    },
  },
})

-- To get fzf loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
telescope.load_extension("fzf")
telescope.load_extension("make")

-----------------------------------------
-- Telescope keymaps
-----------------------------------------

-- Git Filer or all Files
local km = require("haykot.keymaps")
km.nnoremap("<leader>ff", function()
  require("haykot.telescope").project_files()
end)

-- Search Dotfiles from anywhere
km.nnoremap("<leader>fd", function()
  require("haykot.telescope").dotfiles()
end)

km.nnoremap("<leader>fm", function()
  require("haykot.telescope").taskfile()
end)

-- Live Grep Search
km.nnoremap("<leader>fg", function()
  require("telescope.builtin").live_grep()
end)

-- Search Current Open Buffers
km.nnoremap("<leader>fb", function()
  require("telescope.builtin").buffers()
end)

-- Search Help Tags
km.nnoremap("<leader>fh", function()
  require("telescope.builtin").help_tags()
end)

km.nnoremap("<leader>fib", function()
  require("telescope.builtin").live_grep({ search_dirs = { vim.fn.expand("%:p") } })
end)


