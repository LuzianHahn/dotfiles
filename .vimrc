
" Vundle Settings
set nocompatible
filetype off
set rtp+=~/.vim/plugins/Vundle.vim
call vundle#begin('~/.vim/plugins')
Plugin 'VundleVim/Vundle.vim'
call vundle#end()
filetype on

" Turn syntax highlighting on.
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
