return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local function location()
        local line = vim.fn.line(".")
        local col = vim.fn.virtcol(".")
        return string.format("Ln %d,Col %d", line, col)
      end
      local diagnostics = {
        "diagnostics",

        sources = { "nvim_diagnostic" },
        sections = { "error", "warn" },

        diagnostics_color = {
          error = "Statusline",
          warn = "Statusline",
          info = "Statusline",
          hint = "Statusline",
        },

        symbols = {
          error = "󰅚 " .. " ",
          warn = "󰀪 " .. " ",
          info = "󰋽 " .. " ",
          hint = "󰌶 " .. " ",
        },
        colored = false, -- Displays diagnostics status in color if set to true.
        update_in_insert = false, -- Update diagnostics in insert mode.
        always_visible = true, -- Show diagnostics even if there are none.
      }
      local filetype = function()
        return vim.bo.filetype
      end

      require("lualine").setup({
        options = { theme = "tokyonight" },
        sections = {
          lualine_a = { "branch" },
          lualine_b = { { "filename", path = 1 } },
          lualine_c = { diagnostics },
          lualine_x = { location },
          lualine_z = { "progress" },
        },
      })
    end,
  },
}
