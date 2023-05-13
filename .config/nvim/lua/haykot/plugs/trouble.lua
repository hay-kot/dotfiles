return {
  -- Trouble LSP Diagnostics
  "folke/trouble.nvim",
  dependencies = "nvim-tree/nvim-web-devicons",
  config = function()
    require("trouble").setup({
      action_keys = {
        jump = { "o", "<tab", },
        jump_close = { "<CR>" },
      },
    })
  end,
  keys = {
    --    { "<leader>ff", M.project_files, desc = "find file" },
    { "<leader>xx", ":TroubleToggle<CR>",                       desc = "toggle lsp diagnostics" },
    { "<leader>xw", ":TroubleToggle workspace_diagnostics<CR>", desc = "workspace diagnostics" },
    { "<leader>xd", ":TroubleToggle document_diagnostics<CR>",  desc = "document diagnostics" },
  },
}
