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
      "tsserver",
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

    require("mason-lspconfig").setup({
      ensure_installed = servers,
      automatic_installation = false,
    })
  end,
}
