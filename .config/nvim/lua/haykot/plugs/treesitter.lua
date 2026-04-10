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
    require("nvim-treesitter").setup({
      auto_install = true,
    })

    vim.treesitter.language.register("bash", "zsh")

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        local ft = vim.bo[args.buf].filetype
        if ft ~= "" and vim.treesitter.language.get_lang(ft) then
          pcall(vim.treesitter.start, args.buf)
        end
      end,
    })
  end,
}
