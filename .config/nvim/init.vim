set tabstop=4 softtabstop=4
set shiftwidth=4
set expandtab
set smartindent
set relativenumber
set nu
set nohlsearch
set hidden
set noerrorbells
set nowrap

set noswapfile
set nobackup
set undodir=~/.vim/undodir
set undofile

set incsearch
set scrolloff=8

set signcolumn=yes

call plug#begin('~/.vim/plugged')

Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'airblade/vim-gitgutter'
Plug 'ayu-theme/ayu-vim' " or other package manager

call plug#end()

let g:coc_global_extensions = [
    \ 'coc-pairs',
    \ 'coc-json',
    \ 'coc-prettier',
    \]

set termguicolors     " enable true colors support
let ayucolor="dark"   " for dark version of theme
colorscheme ayu

let mapleader = " "
noremap <leader>fg :lua <cmd>Telescope git_files<cr>
nnoremap <leader>ff :lua <cmd>Telescope find_files<cr>


fun! TrimWhitespace()
    let l:save = winsaveview()
    keeppatterns %s/\s\+$//e
    call winrestview(l:save)
endfun

augroup HAY_KOT
    autocmd!
    autocmd BufWritePre * :call TrimWhitespace()
augroup END


