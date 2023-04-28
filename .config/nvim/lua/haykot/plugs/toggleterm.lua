-- Lazy Loaded lazygit termina variable. Initialized in config setup method
local lazygit = nil
local local_term = nil

local cd_command = function(term, cmd, dir)
  local toggleterm = require("toggleterm")

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

return {
  "akinsho/toggleterm.nvim",
  config = function()
    local toggleterm = require("toggleterm")
    local km = require("haykot.keymaps")

    toggleterm.setup({
      size = 20,
      insert_mappings = false,
      hide_numbers = true,
      shade_terminals = true,
      shading_factor = 2,
      on_open = function()
        km.keymap("t", "<Esc>", ":ToggleTerm<CR>")
      end,
      on_close = function()
      end,
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

    ---@diagnostic disable-next-line: duplicate-set-field
    _G.set_terminal_keymaps = function()
      local opts = { noremap = true }
      vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-h>", [[<C-\><C-n><C-W>h]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", [[<C-\><C-n><C-W>j]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-k>", [[<C-\><C-n><C-W>k]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-l>", [[<C-\><C-n><C-W>l]], opts)
    end

    vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

    local Terminal = require("toggleterm.terminal").Terminal

    lazygit = Terminal:new({ cmd = "lazygit", hidden = true })

    local_term = Terminal:new({
      -- whatever options you want, EXCEPT:
      -- DO NOT supply `cmd`. We have to modify it and send directly.
      size = 80,
      close_on_exit = true,
    })
  end,
  keys = {
    {
      "<leader>g",
      function()
        lazygit:toggle()
      end,
      desc = "toggle lazygit",
    },
    { "<leader>t", ":ToggleTerm<CR>", desc = "toggle terminal" },
    {
      "<leader>lt",
      function()
        local dir = current_dir()
        cd_command(local_term, "", dir)
      end,
      desc = "toggle local terminal",
    },
  },
}
