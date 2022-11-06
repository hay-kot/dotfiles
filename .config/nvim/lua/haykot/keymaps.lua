-- Shorten function name
local keymap = vim.keymap.set

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local M = {}

function bind(op, outer_opts)
    outer_opts = outer_opts or {noremap = true, silent = true}
    return function(lhs, rhs, opts)
        opts = vim.tbl_extend("force",
            outer_opts,
            opts or {}
        )
        vim.keymap.set(op, lhs, rhs, opts)
    end
end

M.nmap = bind("n", {noremap = false})
M.nnoremap = bind("n")
M.vnoremap = bind("v")
M.xnoremap = bind("x")
M.inoremap = bind("i")

-- Global Keymaps

-- Reload Config
M.nnoremap("<leader>ev", ":e ~/.config/nvim/init.lua<CR>")
M.nnoremap("<leader>sv", ":source ~/.config/nvim/init.lua<CR>")

return M
