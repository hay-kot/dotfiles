return {
  "williamboman/mason.nvim",
  dependencies = { "williamboman/mason-lspconfig.nvim" },
  config = function()
    local servers = {
      "eslint",
      "golangci_lint_ls",
      "gopls",
      "html",
      "jsonls",
      "pyright",
      "tailwindcss",
      "volar",
      "dockerls",
      "docker_compose_language_service",
      "ansiblels",
      "ruff_lsp",
    }

    require("mason").setup({
      ui = {
        border = "none",
        icons = {
          package_installed = "◍",
          package_pending = "◍",
          package_uninstalled = "◍",
        },
      },
      log_level = vim.log.levels.INFO,
      max_concurrent_installers = 4,
    })

    local lsp_zero = require("lsp-zero")

    require("mason-lspconfig").setup({
      ensure_installed = servers,
      automatic_installation = false,
      handlers = {
        lsp_zero.default_setup,

        --------------------------------------------
        -- Bash / Zsh
        bashls = function()
          require("lspconfig").bashls.setup({
            filetypes = { "sh", "zsh" },
          })
        end,
        --------------------------------------------
        -- Vue / Typescript
        volar = function()
          require("lspconfig").volar.setup({
            on_attach = function(client)
              client.server_capabilities.documentFormattingProvider = false
              client.server_capabilities.documentRangeFormattingProvider = false
            end,
          })
        end,
        ts_ls = function()
          local vue_typescript_plugin = require("mason-registry").get_package("vue-language-server"):get_install_path()
            .. "/node_modules/@vue/language-server"
            .. "/node_modules/@vue/typescript-plugin"

          require("lspconfig").ts_ls.setup({
            init_options = {
              plugins = {
                {
                  name = "@vue/typescript-plugin",
                  location = vue_typescript_plugin,
                  languages = { "javascript", "typescript", "vue" },
                },
              },
            },
            filetypes = {
              "javascript",
              "javascriptreact",
              "javascript.jsx",
              "typescript",
              "typescriptreact",
              "typescript.tsx",
              "vue",
            },
          })
        end,
        eslint = function()
          require("lspconfig").eslint.setup({
            settings = {
              packageManager = "pnpm",
            },
            on_attach = function(_, bufnr)
              vim.api.nvim_create_autocmd("BufWritePre", {
                buffer = bufnr,
                command = "EslintFixAll",
              })
            end,
          })
        end,
        html = function()
          require("lspconfig").eslint.setup({
            init_options = {
              configurationSection = { "html", "css", "javascript" },
              embeddedLanguages = {
                css = true,
                javascript = true,
              },
              provideFormatter = false, -- fallback to null-ls/prettier
            },
            on_attach = function(client, bufnr)
              client.server_capabilities.documentFormattingProvider = false
              client.server_capabilities.documentRangeFormattingProvider = false
            end,
          })
        end,
        --------------------------------------------
        -- Lua
        lua_ls = function()
          -- fix vim global in lua
          local lua_opts = lsp_zero.nvim_lua_ls()
          require("lspconfig").lua_ls.setup(lua_opts)
        end,
        --------------------------------------------
        -- Yaml
        yamlls = function()
          require("lspconfig").yamlls.setup({
            settings = {
              yaml = {
                keyOrdering = false, -- Disabled Ordered Fields Linting
              },
            },
          })
        end,
        gopls = function()
          require("lspconfig").gopls.setup({
            on_attach = function(client)
              -- Lua function
              local function IfErr()
                local bpos = vim.fn.wordcount().cursor_bytes
                local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)

                -- Run the external command with "iferr" and capture the output
                local out = vim.fn.systemlist("iferr -pos " .. bpos, content)

                -- Check if there are any errors
                if #out == 1 then
                  print("IfErr() -> no err found")
                  return
                end

                local current_line, current_col = unpack(vim.api.nvim_win_get_cursor(0))

                -- Get the current line's indentation
                local current_indent = vim.fn.indent(current_line)

                -- Construct the indented multiline text
                local indented_text = {}
                for _, line in ipairs(out) do
                  table.insert(indented_text, string.rep(" ", current_indent) .. line)
                end

                table.insert(indented_text, "")

                -- Move the cursor to the line below the current line
                vim.api.nvim_win_set_cursor(0, { current_line + 1, 0 })

                -- Insert the indented multiline text at the current cursor position
                vim.api.nvim_put(indented_text, "", false, true)

                -- Move the cursor to the end of the last line of the inserted text
                vim.api.nvim_win_set_cursor(0, { current_line + #out, current_col + #indented_text[#indented_text] })
              end

              local km = require("haykot.keymaps")
              km.nnoremap("<leader>er", IfErr, { desc = "Run iferr" })
            end,
          })
        end,
      },
    })
  end,
}
