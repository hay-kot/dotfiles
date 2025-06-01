local km = require("haykot.keymaps")

-- Copy/Pasta from Kickstart.nvim
-- See
--  - https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua#L466
return {
  -- Main LSP Configuration
  "neovim/nvim-lspconfig",
  dependencies = {
    -- Automatically install LSPs and related tools to stdpath for Neovim
    -- Mason must be loaded before its dependents so we need to set it up here.
    -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
    {
      "williamboman/mason.nvim",
      opts = {
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
      },
    },
    { "mason-org/mason-lspconfig.nvim", config = function() end },
    "WhoIsSethDaniel/mason-tool-installer.nvim",

    -- Useful status updates for LSP.
    { "j-hui/fidget.nvim",              opts = {} },

    -- Autocompletion - lsp
    { "hrsh7th/cmp-nvim-lsp" },
  },
  config = function()
    -- Configure server capabilities and setup
    local function config_servers()
      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())

      -- can be opts table or a function that returns options.
      local servers = {
        clangd = {},
        pyright = {},
        rust_analyzer = {},
        bashls = {
          filetypes = { "sh", "zsh" },
        },
        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = "Replace",
              },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              diagnostics = { disable = { "missing-fields" } },
            },
          },
        },
        yamlls = {
          settings = {
            yaml = {
              keyOrdering = false, -- Disabled Ordered Fields Linting
            },
          },
        },

        -- --------------------------------------------------------
        -- Go Servers
        -- --------------------------------------------------------
        gopls = {
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

            km.nnoremap("<leader>lat", ":GoAddTag<CR>")
          end,
        },

        -- --------------------------------------------------------
        -- Web Dev Servers
        -- --------------------------------------------------------
        ts_ls = {
          filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue", "svelte" },
          init_options = {
            plugins = {
              {
                name = "@vue/typescript-plugin",
                location = vim.fn.expand("$MASON/packages/vue-language-server/node_modules/@vue/language-server"),
                languages = { "vue" },
              },
            },
          },
        },
        vue_ls = {
          on_attach = function(client, _)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end,
        },
        eslint = {
          settings = {
            packageManager = "pnpm",
          },
          on_attach = function(_, bufnr)
            vim.api.nvim_create_autocmd("BufWritePre", {
              buffer = bufnr,
              command = "EslintFixAll",
            })
          end,
        },
        html = {
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
        },

        -- Patch init options to support v1 & v2
        golangci_lint_ls = {
          init_options = (function()
            local pipe = io.popen("golangci-lint version --short 2>/dev/null")
            if pipe == nil then
              return {}
            end

            local version = pipe:read("*a")
            pipe:close()

            local major_version = tonumber(version:match("^v?(%d+)%."))
            if major_version and major_version >= 2 then
              return {
                command = {
                  "golangci-lint",
                  "run",
                  "--output.json.path",
                  "stdout",
                  "--show-stats=false",
                  "--issues-exit-code=1",
                },
              }
            else
              -- Default v1 config - NOTE: major_version is nil for v1 since --short is an invalid flag
              return {
                command = {
                  "golangci-lint",
                  "run",
                  "--output-format=json",
                  "--issues-exit-code=1",
                },
              }
            end
          end)(),
        },

        --[[ harper_ls = { ]]
        --[[   settings = { ]]
        --[[     ["harper-ls"] = { ]]
        --[[       userDictPath = "~/.config/nvim/lua/haykot/plugs/dict/dict.txt", ]]
        --[[       fileDictPath = "", ]]
        --[[       linters = { ]]
        --[[         SpellCheck = true, ]]
        --[[         SpelledNumbers = false, ]]
        --[[         AnA = true, ]]
        --[[         SentenceCapitalization = false, ]]
        --[[         UnclosedQuotes = true, ]]
        --[[         WrongQuotes = false, ]]
        --[[         LongSentences = false, ]]
        --[[         RepeatedWords = true, ]]
        --[[         Spaces = false, ]]
        --[[         Matcher = true, ]]
        --[[         CorrectNumberSuffix = false, ]]
        --[[       }, ]]
        --[[       codeActions = { ]]
        --[[         ForceStable = false, ]]
        --[[       }, ]]
        --[[       markdown = { ]]
        --[[         IgnoreLinkTitle = false, ]]
        --[[       }, ]]
        --[[       diagnosticSeverity = "hint", ]]
        --[[       isolateEnglish = false, ]]
        --[[       dialect = "American", ]]
        --[[     }, ]]
        --[[   }, ]]
        --[[ }, ]]
      }

      -- Identify disabled servers for exclusion
      local disabled_servers = {}
      for server_name, server in pairs(servers) do
        if server.enabled == false then
          table.insert(disabled_servers, server_name)
        end
      end

      -- Pre-configure all servers with capabilities
      for server_name, server in pairs(servers) do
        -- server can be a function or a table, if function execute and set opts to be result
        if type(server) == "function" then
          server = server()
        end

        -- This handles overriding only values explicitly passed
        -- by the server configuration above. Useful when disabling
        -- certain features of an LSP (for example, turning off formatting for ts_ls)
        server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
        vim.lsp.config(server_name, server)
      end

      return servers, disabled_servers
    end

    -- Configure servers and get disabled list
    local servers, disabled_servers = config_servers()

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
      callback = function()
        km.nnoremap("<leader>le", function()
          vim.diagnostic.goto_next()
        end, { desc = "Go to next diagnostic", buffer = true })

        km.nnoremap("<leader>lE", function()
          vim.diagnostic.goto_prev()
        end, { desc = "Go to previous diagnostic", buffer = true })

        km.nnoremap("K", function()
          vim.lsp.buf.hover()
        end, { desc = "Show hover information" })

        km.nnoremap("<leader>lx", function()
          vim.diagnostic.open_float()
        end, { desc = "Open diagnostic float" })

        km.nnoremap("[d", function()
          vim.diagnostic.goto_next()
        end, { desc = "Jump to next diagnostic" })

        km.nnoremap("]d", function()
          vim.diagnostic.goto_prev()
        end, { desc = "Jump to previous diagnostic" })

        km.nnoremap("<leader>lca", function()
          vim.lsp.buf.code_action()
        end, { desc = "Show code actions" })

        km.nnoremap("<leader>lr", function()
          vim.lsp.buf.rename()
        end, { desc = "Rename symbol" })

        km.inoremap("<C-h>", function()
          vim.lsp.buf.signature_help()
        end, { desc = "Show signature help" })

        km.nnoremap("<leader>lf", "<cmd>lua vim.lsp.buf.format({async=true})<CR>", { desc = "format file" })
        -- command Format
        vim.cmd([[command! Fmt execute 'lua vim.lsp.buf.format()']])
      end,
    })

    --  Configure LSP hover with borders
    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
      border = "rounded",
    })

    -- Also add borders to signature help if you want consistency
    vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
      border = "rounded",
    })

    -- Diagnostic Config
    -- See :help vim.diagnostic.Opts
    vim.diagnostic.config({
      severity_sort = true,
      float = { border = "rounded", source = false },
      underline = { severity = vim.diagnostic.severity.ERROR },
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "󰅚 ",
          [vim.diagnostic.severity.WARN] = "󰀪 ",
          [vim.diagnostic.severity.INFO] = "󰋽 ",
          [vim.diagnostic.severity.HINT] = "󰌶 ",
        },
      },
      virtual_text = {
        source = false,
        spacing = 2,
        format = function(diagnostic)
          local diagnostic_message = {
            [vim.diagnostic.severity.ERROR] = diagnostic.message,
            [vim.diagnostic.severity.WARN] = diagnostic.message,
            [vim.diagnostic.severity.INFO] = diagnostic.message,
            [vim.diagnostic.severity.HINT] = diagnostic.message,
          }
          return diagnostic_message[diagnostic.severity]
        end,
      },
    })

    local ensure_installed = vim.tbl_keys(servers or {})
    vim.list_extend(ensure_installed, {
      "stylua", -- Used to format Lua code
    })
    require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

    -- Mason v2 configuration with automatic_enable instead of handlers
    require("mason-lspconfig").setup({
      ensure_installed = vim.tbl_keys(servers),
      automatic_enable = {
        exclude = disabled_servers,
      },
    })
  end,
}
