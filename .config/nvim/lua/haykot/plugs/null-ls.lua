return {
  -- Null LS
  "nvimtools/none-ls.nvim",
  config = function()
    -- LSP Zero null-ls
    local null_ls = require("null-ls")

    local eslint_configs = {
      ".eslint.json",
      ".eslintrc.js",
      ".eslintrc",
      "./frontend/.eslint.json",
      "./frontend/.eslintrc.js",
      "./frontend/.eslintrc",
    }

    local prettier_configs = {
      ".prettierrc",
      ".prettierrc.js",
      ".prettierrc.json",
      "./frontend/.prettierrc",
      "./frontend/.prettierrc.js",
      "./frontend/.prettierrc.json",
    }

    local feature = require("haykot.lib.features")

    -- Only use gofumpt on personal laptop - work uses
    -- standard gofmt.
    local goformatter = null_ls.builtins.formatting.gofmt
    if feature.enabled("gofumpt", false) then
      goformatter = null_ls.builtins.formatting.gofumpt
    end

    null_ls.setup({
      debug = false,
      sources = {
        -- JavaScript
        null_ls.builtins.formatting.prettier.with({
          condition = function(null_utils)
            local has_eslint = null_utils.has_file(eslint_configs)
            local has_prettier = null_utils.has_file(prettier_configs)

            if has_prettier then
              return true
            elseif has_eslint then
              return false
            else
              return true
            end
          end,
        }),

        -- Lua
        null_ls.builtins.formatting.stylua,

        -- Go
        goformatter,
        null_ls.builtins.formatting.goimports,

        -- Sql Formatter
        null_ls.builtins.formatting.sql_formatter.with({ command = { "sleek" } }),
      },
    })
  end,
}
