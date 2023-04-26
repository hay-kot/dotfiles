-- Shorten function name
local keymap = vim.keymap.set

--Remap space as leader key
keymap("", "<Space>", "<Nop>", { noremap = true, silent = true })
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
M.nnoremap("<leader>q", ":bd<CR>", { desc = "close buffer" })
M.nnoremap("<leader>Q", ":bd!<CR>", { desc = "force close buffer" })

-- set sbr to Split Buffer righ
M.nnoremap("<leader>sbr", ":vsplit<CR>")

-- Better window navigation
M.nnoremap("<C-h>", "<C-w>h", { desc = "move to left window" })
M.nnoremap("<C-j>", "<C-w>j", { desc = "move to bottom window" })
M.nnoremap("<C-l>", "<C-w>l", { desc = "move to right window" })
M.nnoremap("<C-k>", "<C-w>k", { desc = "move to top window" })

-- Visual --
-- Stay in indent mode
M.vnoremap("<", "<gv", { desc = "indent left" })
M.vnoremap(">", ">gv", { desc = "indent right" })

-- Move text up and down
M.vnoremap("<A-j>", ":m .+1<CR>==", { desc = "move line down" })
M.vnoremap("<A-k>", ":m .-2<CR>==", { desc = "move line up" })

-- Visual Block --
-- Move text up and down
M.xnoremap("J", ":move '>+1<CR>gv-gv")
M.xnoremap("K", ":move '<-2<CR>gv-gv")
M.xnoremap("<A-j>", ":move '>+1<CR>gv-gv")
M.xnoremap("<A-k>", ":move '<-2<CR>gv-gv")

-- Reload Config
M.nnoremap("<leader>sv", ":source ~/.config/nvim/init.lua<CR>")

-- Center Buffer
M.nnoremap("<C-d>", "<C-d>zz")
M.nnoremap("<C-u>", "<C-u>zz")

-- Hide search highlight
M.nnoremap("<leader>/", ":noh<cr>")

-- Keeps the cursor in the same place when pulling next line up
M.nnoremap("J", "mzJ`z")

-- Allow Search Terms to say centered in buffer
M.nnoremap("n", "nzzzv")
M.nnoremap("N", "Nzzzv")

-- Keep Paste over from yanking to nvim register
M.xnoremap("<leader>p", '"_dP')

return M
