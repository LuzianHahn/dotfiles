" Plugins {{{
packadd vim-fugitive
" }}}


" Settings {{{
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

" Settings specifically for vim files
augroup filetype_vim
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker	"set for vim files marker as foldmethod
augroup END

" }}}

" Mappings {{{
nnoremap gb :Git blame<CR>
" }}}
