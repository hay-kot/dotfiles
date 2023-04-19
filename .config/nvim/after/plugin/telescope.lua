local ok, telescope = pcall(require, "telescope")
if not ok then
	return
end

-- close on escape
local actions = require("telescope.actions")

telescope.setup({
	defaults = {
		prompt_prefix = " ",
		mappings = {
			i = {
				["<esc>"] = actions.close,
			},
		},
	},
	extensions = {
		fzf = {
			fuzzy = true, -- false will only do exact matching
			override_generic_sorter = true, -- override the generic sorter
			override_file_sorter = true, -- override the file sorter
			case_mode = "smart_case", -- or "ignore_case" or "respect_case"
			-- the default case_mode is "smart_case"
		},
	},
})

-- To get fzf loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
telescope.load_extension("fzf")

-- telescope keymaps
local km = require("haykot.keymaps")
km.nnoremap("<leader>ff", function()
	require("haykot.telescope").project_files()
end) -- git files or all files
km.nnoremap("<leader>fd", function()
	require("haykot.telescope").dotfiles()
end)
km.nnoremap("<leader>fg", function()
	require("telescope.builtin").live_grep()
end)
km.nnoremap("<leader>fb", function()
	require("telescope.builtin").buffers()
end)
km.nnoremap("<leader>fh", function()
	require("telescope.builtin").help_tags()
end)
