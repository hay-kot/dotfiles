return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
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

    require("nvim-treesitter").install({
      "bash",
      "c",
      "go",
      "gomod",
      "gosum",
      "javascript",
      "json",
      "lua",
      "markdown",
      "markdown_inline",
      "python",
      "rust",
      "toml",
      "typescript",
      "vim",
      "vimdoc",
      "yaml",
    })

    vim.treesitter.language.register("bash", "zsh")

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("treesitter", { clear = true }),
      pattern = "*",
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
