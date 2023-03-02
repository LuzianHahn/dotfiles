
" Vundle Settings
set nocompatible
filetype off
set rtp+=~/.vim/plugins/Vundle.vim
call vundle#begin('~/.vim/plugins')
Plugin 'VundleVim/Vundle.vim'
Plugin 'tpope/vim-fugitive'
Plugin 'rhysd/git-messenger.vim'
call vundle#end()
filetype on


syntax on

" Let's save undo info!
if !isdirectory($HOME."/.vim")
    call mkdir($HOME."/.vim", "", 0770)
endif
if !isdirectory($HOME."/.vim/undo-dir")
    call mkdir($HOME."/.vim/undo-dir", "", 0700)
endif
set undodir=~/.vim/undo-dir
set undofile
set colorcolumn=121				"mark theoretical line limit of 120 chars"
set number					"activate line numbers

nnoremap gb :Git blame<CR>

