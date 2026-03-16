return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  dependencies = {
    {
      "nvim-treesitter/nvim-treesitter-context",
      config = function()
        require("treesitter-context").setup({
          enable = true,
        })

        vim.api.nvim_create_user_command("ToggleTreeSitterContext", function()
          require("treesitter-context").toggle()
        end, { range = false, nargs = 0, desc = "Toggle TreeSitter Context" })
      end,
    },
  },
  config = function()
    require("nvim-treesitter").setup()

    -- Enable treesitter highlighting and indentation
    vim.treesitter.language.register("bash", "zsh")

    -- Auto-install parsers when entering a buffer
    vim.api.nvim_create_autocmd("FileType", {
      callback = function()
        pcall(vim.treesitter.start)
      end,
    })
  end,
}
