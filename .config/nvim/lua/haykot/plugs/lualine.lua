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
          error = "" .. " ",
          warn = "" .. " ",
          info = "I",
          hint = "H",
        },
        colored = false,          -- Displays diagnostics status in color if set to true.
        update_in_insert = false, -- Update diagnostics in insert mode.
        always_visible = true,    -- Show diagnostics even if there are none.
      }
      local copilot = function()
        local buf_clients = vim.lsp.get_active_clients({ bufnr = 0 })
        if #buf_clients == 0 then
          return "LSP Inactive"
        end

        local buf_ft = vim.bo.filetype
        local buf_client_names = {}
        local copilot_active = false

        -- add client
        for _, client in pairs(buf_clients) do
          if client.name ~= "null-ls" and client.name ~= "copilot" then
            table.insert(buf_client_names, client.name)
          end

          if client.name == "copilot" then
            copilot_active = true
          end
        end

        if copilot_active then
          return lvim.icons.git.Octoface
        end
        return ""
      end

      local filetype = function()
        return vim.bo.filetype
      end

      local colors = {
        fg = "#76787d",
        bg = "#252829",
      }
      require("lualine").setup({
        options = {
          theme = {
            normal = {
              a = { fg = colors.fg, bg = colors.bg },
              b = { fg = colors.fg, bg = colors.bg },
              c = { fg = colors.fg, bg = colors.bg },
            },
            insert = { a = { fg = colors.fg, bg = colors.bg }, b = { fg = colors.fg, bg = colors.bg } },
            visual = { a = { fg = colors.fg, bg = colors.bg }, b = { fg = colors.fg, bg = colors.bg } },
            command = { a = { fg = colors.fg, bg = colors.bg }, b = { fg = colors.fg, bg = colors.bg } },
            replace = { a = { fg = colors.fg, bg = colors.bg }, b = { fg = colors.fg, bg = colors.bg } },

            inactive = {
              a = { bg = colors.fg, fg = colors.bg },
              b = { bg = colors.fg, fg = colors.bg },
              c = { bg = colors.fg, fg = colors.bg },
            },
          },
        },
        sections = {
          lualine_a = { "branch" },
          lualine_b = { { "filename", path = 1 } },
          lualine_c = { diagnostics },
          lualine_x = { location },
          lualine_y = { copilot, filetype },
          lualine_z = { "progress" },
        },
      })
    end,
  },
}
