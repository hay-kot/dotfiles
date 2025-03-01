return {
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",

  dependencies = {
    -- Snippets
    {
      "L3MON4D3/LuaSnip",
      build = (function()
        -- Build Step is needed for regex support in snippets.
        -- This step is not supported in many windows environments.
        -- Remove the below condition to re-enable on windows.
        if vim.fn.has("win32") == 1 or vim.fn.executable("make") == 0 then
          return
        end
        return "make install_jsregexp"
      end)(),
      version = "v2.*",
      config = function()
        -- log to local file
        ls = require("luasnip")
        -- Map "Ctrl + p" (in insert mode)
        -- to expand snippet and jump through fields.
        vim.api.nvim_set_keymap(
          "i",
          "<Tab>",
          "luasnip#expand_or_jumpable() ? '<Plug>luasnip-expand-or-jump' : '<Tab>'",
          { expr = true, silent = true }
        )
        vim.api.nvim_set_keymap("i", "<S-Tab>", "<cmd>lua require'luasnip'.jump(-1)<CR>", { silent = true })
        vim.api.nvim_set_keymap("s", "<Tab>", "<cmd>lua require('luasnip').jump(1)<CR>", { silent = true })
        vim.api.nvim_set_keymap("s", "<S-Tab>", "<cmd>lua require('luasnip').jump(-1)<CR>", { silent = true })

        require("luasnip.loaders.from_vscode").lazy_load({
          exclude = { "go" },
        })

        require("luasnip.loaders.from_vscode").lazy_load({
          paths = {
            "~/.config/nvim/lua/haykot/plugs/snips",
          },
        })
      end,
      dependencies = {
        { "rafamadriz/friendly-snippets" },
      },
    },

    -- Sources
    { "hrsh7th/nvim-cmp" },
    { "hrsh7th/cmp-buffer" },
    { "hrsh7th/cmp-path" },
    { "hrsh7th/cmp-nvim-lua" },
    { "saadparwaiz1/cmp_luasnip" },
  },

  config = function()
    local cmp = require("cmp")

    cmp.setup({
      preselect = "none",
      formatting = cmp_format,
      mapping = cmp.mapping.preset.insert({
        -- Required or else it will drive you crazy
        ["<CR>"] = nil,
        ["<C-m>"] = nil,
        -- scroll up and down the documentation window
        ["<C-u>"] = cmp.mapping.scroll_docs(-4),
        ["<C-d>"] = cmp.mapping.scroll_docs(4),
        -- Configure Ctrl-Space to trigger completion
        ["<C-Space>"] = cmp.mapping.complete(),
        -- Configure Ctrl-y to confirm completion
        ["<S-CR>"] = cmp.mapping.confirm({ select = true }),

        -- Super tab
        --  - Source: https://lsp-zero.netlify.app/docs/autocomplete.html#enable-super-tab
        ["<Tab>"] = cmp.mapping(function(fallback)
          local luasnip = require("luasnip")
          local col = vim.fn.col(".") - 1

          if cmp.visible() then
            cmp.select_next_item({ behavior = "select" })
          elseif luasnip.expand_or_locally_jumpable() then
            luasnip.expand_or_jump()
          elseif col == 0 or vim.fn.getline("."):sub(col, col):match("%s") then
            fallback()
          else
            cmp.complete()
          end
        end, { "i", "s" }),

        -- Super shift tab
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          local luasnip = require("luasnip")

          if cmp.visible() then
            cmp.select_prev_item({ behavior = "select" })
          elseif luasnip.locally_jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      }),
      sources = {
        -- Copilot Source
        { name = "copilot", group_index = 2 },
        { name = "nvim_lsp", max_item_count = 100 },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
        { name = "nvim_lsp_signature_help" },
      },
      snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)
        end,
      },
    })
  end,
}
