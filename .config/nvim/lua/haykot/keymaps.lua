-- Shorten function name
local keymap = vim.keymap.set

local opts = { noremap = true, silent = true }
--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local M = {}

local function bind(op, outer_opts)
  outer_opts = outer_opts or { noremap = true, silent = true }
  return function(lhs, rhs, opts)
    opts = vim.tbl_extend("force", outer_opts, opts or {})
    vim.keymap.set(op, lhs, rhs, opts)
  end
end

M.keymap = keymap
M.nmap = bind("n", { noremap = false })
M.nnoremap = bind("n")
M.vnoremap = bind("v")
M.xnoremap = bind("x")
M.inoremap = bind("i")

-- Close Buffers
keymap("n", "<leader>q", ":bd<CR>", opts)
keymap("n", "<leader>Q", ":bd!<CR>", opts)

-- LSP Bindings
-- format
keymap("n", "<leader>lf", "<cmd>lua vim.lsp.buf.format()<CR>", opts)
-- command Format
vim.cmd([[command! Format execute 'lua vim.lsp.buf.format()']])

-- set sbr to Split Buffer righ
M.nnoremap("<leader>sbr", ":vsplit<CR>")

-- Better window navigation
M.nnoremap("<C-h>", "<C-w>h", opts)
M.nnoremap("<C-j>", "<C-w>j", opts)
M.nnoremap("<C-l>", "<C-w>l", opts)
M.nnoremap("<C-k>", "<C-w>k", opts)

-- Visual --
-- Stay in indent mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Move text up and down
keymap("v", "<A-j>", ":m .+1<CR>==", opts)
keymap("v", "<A-k>", ":m .-2<CR>==", opts)
keymap("v", "p", '"_dP', opts)

-- Visual Block --
-- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
keymap("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
keymap("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

-- Reload Config
M.nnoremap("<leader>sv", ":source ~/.config/nvim/init.lua<CR>")

-- Center Buffer
M.nnoremap("<C-d>", "<C-d>zz")
M.nnoremap("<C-u>", "<C-u>zz")

-- Hide search highlight
M.nnoremap("<leader>/", ":noh<cr>", opts)

-- Keeps the cursor in the same place when pulling next line up
M.nnoremap("J", "mzJ`z", opts)

-- Allow Search Terms to say centered in buffer
M.nnoremap("n", "nzzzv", opts)
M.nnoremap("N", "Nzzzv", opts)

-- Keep Paste over from yanking to nvim register
M.xnoremap("<leader>p", '"_dP', opts)

return M
