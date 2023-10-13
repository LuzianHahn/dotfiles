" Plugins {{{
packadd vim-fugitive
" }}}

" Settings {{{
filetype plugin indent on
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
set cursorline              "activate underline of cursor
set foldmethod=indent
set expandtab shiftwidth=4 softtabstop=4 tabstop=4 autoindent

set wildmenu
set wildmode=list:longest
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx

set hlsearch        " Enable search highlighting
set incsearch       " Incremental search highlighting as you type
" }}}

" Functions {{{
function ToggleComment(comment_char)
  let l:escaped_comment_char = escape(a:comment_char, '\')
  let l:is_comment = match(getline('.'), '^ *'.escaped_comment_char) >= 0
  if is_comment
    execute 's/\(^\s*\)\@<=' . l:escaped_comment_char . ' //'
  else
    execute 's/^\(\s*\)/\1' . l:escaped_comment_char . ' /'
  endif
  normal! j
endfunction
" }}}

" Mappings {{{
nnoremap gb :Git blame<CR>
nnoremap <C-K> :call ToggleComment('#')<CR>
" }}}

" File Type specific Settings {{{

" Settings specifically for vim files
augroup filetype_vim
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker	"set for vim files marker as foldmethod
    autocmd FileType vim nnoremap <C-K> :call ToggleComment('"')<CR>
augroup END

" Settings specifically for python files
augroup filetype_python
    autocmd!
    autocmd FileType python let g:python_recommended_style = 0
augroup END

" }}}
