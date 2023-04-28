local globals = require("haykot.lib.globals")

return {
  priority = 99,
  lazy = true,
  "nvim-tree/nvim-tree.lua",
  tag = "nightly", -- optional, updated every week. (see issue #1193)
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local nvim_tree = require("nvim-tree")
    local nvim_tree_config = require("nvim-tree.config")

    local tree_cb = nvim_tree_config.nvim_tree_callback

    local HEIGHT_RATIO = 0.8 -- You can change this
    local WIDTH_RATIO = 0.6  -- You can change this too

    nvim_tree.setup({
      git = {
        ignore = false,
      },
      update_focused_file = {
        enable = true,
        update_cwd = true,
      },
      renderer = {
        root_folder_modifier = ":t",
        icons = {
          glyphs = {
            default = "",
            symlink = "",
            folder = {
              arrow_open = "",
              arrow_closed = "",
              default = "",
              open = "",
              empty = "",
              empty_open = "",
              symlink = "",
              symlink_open = "",
            },
            git = {
              unstaged = "",
              staged = "S",
              unmerged = "",
              renamed = "➜",
              untracked = "U",
              deleted = "",
              ignored = "◌",
            },
          },
        },
      },
      diagnostics = {
        enable = true,
        show_on_dirs = true,
        icons = {
          hint = "",
          info = "",
          warning = "",
          error = "",
        },
      },
      view = {
        side = "left",
        mappings = {
          list = {
            { key = { "l", "<CR>", "o" }, cb = tree_cb("edit") },
            { key = "h",                  cb = tree_cb("close_node") },
            { key = "v",                  cb = tree_cb("vsplit") },
            -- <leader><leader> to open tree
            { key = "<leader><leader>",   cb = tree_cb("expand") },
          },
        },
        float = {
          enable = true,
          open_win_config = function()
            local screen_w = vim.opt.columns:get()
            local screen_h = vim.opt.lines:get() - vim.opt.cmdheight:get()
            local window_w = screen_w * WIDTH_RATIO
            local window_h = screen_h * HEIGHT_RATIO
            local window_w_int = math.floor(window_w)
            local window_h_int = math.floor(window_h)
            local center_x = (screen_w - window_w) / 2
            local center_y = ((vim.opt.lines:get() - window_h) / 2) - vim.opt.cmdheight:get()
            return {
              border = "rounded",
              relative = "editor",
              row = center_y,
              col = center_x,
              width = window_w_int,
              height = window_h_int,
            }
          end,
        },
        width = function()
          return math.floor(vim.opt.columns:get() * WIDTH_RATIO)
        end,
      },
      actions = {
        open_file = {
          quit_on_open = true,
        },
      },
    })

    -- This may need to be moved elsewhere?
    local function open_nvim_tree()
      if globals.session_restored then
        return
      end
      require("nvim-tree.api").tree.open()
    end

    vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })
  end,
  keys = {
    { "<leader>ee", ":NvimTreeToggle<cr>", desc = "toggle nvim tree" },
  },
}
