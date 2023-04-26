local status_ok, toggleterm = pcall(require, "toggleterm")
if not status_ok then
	return
end

local km = require("haykot.keymaps")

local open_remap = function()
	km.keymap("t", "<Esc>", ":ToggleTerm<CR>")
end

local close_remap = function() end

toggleterm.setup({
	size = 20,
	insert_mappings = false,
	hide_numbers = true,
	shade_terminals = true,
	shading_factor = 2,
	on_open = open_remap,
	on_close = close_remap,
	start_in_insert = true,
	persist_size = true,
	direction = "float",
	close_on_exit = true,
	float_opts = {
		border = "curved",
		winblend = 0,
		highlights = {
			border = "Normal",
			background = "Normal",
		},
	},
})

_G.set_terminal_keymaps = function()
	local opts = { noremap = true }
	vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
	vim.api.nvim_buf_set_keymap(0, "t", "<C-h>", [[<C-\><C-n><C-W>h]], opts)
	vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", [[<C-\><C-n><C-W>j]], opts)
	vim.api.nvim_buf_set_keymap(0, "t", "<C-k>", [[<C-\><C-n><C-W>k]], opts)
	vim.api.nvim_buf_set_keymap(0, "t", "<C-l>", [[<C-\><C-n><C-W>l]], opts)
end

vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

-- Lazy Git Custom Terminal
--
-- Creates a shared terminal to use for LazyGit.
local Terminal = require("toggleterm.terminal").Terminal
local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })

function ToggleLazyGit()
	lazygit:toggle()
end

km.nnoremap("<leader>g", function()
	ToggleLazyGit()
end, { desc = "open lazygit" })

-- Global Default Terminal
km.nnoremap("<leader>t", ":ToggleTerm<CR>", { desc = "toggle terminal" })

-- Local Directory Terminal
--
-- This section creates a new terminal in the local directory
-- It is removed when toggled EVERY TIME which means you lose history
-- This is a hack since toggle term doesn't support setting the working
-- directory at toggle time.
--
-- See https://github.com/akinsho/toggleterm.nvim/issues/346 for more info
local local_term = Terminal:new({
	-- whatever options you want, EXCEPT:
	-- DO NOT supply `cmd`. We have to modify it and send directly.
	size = 80,
	close_on_exit = true,
})

local cd_command = function(term, cmd, dir)
	if dir then
		cmd = string.format("pushd %s && clear", dir, cmd)
	end

	if not term:is_open() then
		term:open()
	end

	toggleterm.exec(cmd, term.id)
end

local current_dir = function()
	-- regular files have empty string for buftype
	local is_file = vim.api.nvim_buf_get_option(0, "buftype") == ""
	if is_file then
		local filename = vim.api.nvim_buf_get_name(0)
		return vim.fs.dirname(filename)
	end
end

km.nnoremap("<leader>lt", function()
	local dir = current_dir()
	cd_command(local_term, "", dir)
end, { desc = "open local terminal" })
