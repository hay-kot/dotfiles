local fn = vim.fn

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd [[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]]

local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

-- Have packer use a popup window
require("packer").init {
  display = {
    open_fn = function()
      return require("packer.util").float { border = "rounded" }
    end,
  },
}

-- Install your plugins here
return require("packer").startup(function(use)
  -- Base Plugins
  use "wbthomason/packer.nvim" -- Have packer manage itself
  use "nvim-lua/popup.nvim" -- An implementation of the Popup API from vim in Neovim
  use "nvim-lua/plenary.nvim" -- Useful lua functions used ny lots of plugins

  -- Git
  use "airblade/vim-gitgutter" -- Shows a git diff in the gutter (sign column)

  -- Navigation
  use "ThePrimeagen/harpoon" -- pinning files
  use {
    'nvim-telescope/telescope.nvim', tag = '0.1.0', -- Fuzzy finder
    requires = {
      {'nvim-lua/plenary.nvim'}
    }
  }
  use {'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }

  -- Pretty Things
  use { "morhetz/gruvbox", as = "gruvbox" }

  use "kyazdani42/nvim-web-devicons" -- Icons

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)
