" Plugins {{{
packadd vim-fugitive
packadd vim-commentary
packadd fzf.vim
packadd fzf
" coc.nvim requires atleast vim >= 9.0
if v:version >= 900
    packadd coc.nvim
endif
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
set backspace=2     " Allows the removal of newlines and indents in insertmode via backspace button

set wildmenu
set wildmode=list:longest
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx

set hlsearch        " Enable search highlighting
set incsearch       " Incremental search highlighting as you type
" }}}

" Functions {{{
" Call :GFiles when inside a git repo, otherwise :Files
function! ToggleGitFiles()
  " Use systemlist to avoid trailing newline and check exit code
  let l:git_dir = systemlist('git rev-parse --is-inside-work-tree 2>/dev/null')
  if v:shell_error == 0 && len(l:git_dir) > 0 && l:git_dir[0] ==# 'true'
    execute 'GFiles'
  else
    execute 'Files'
  endif
endfunction
" }}}

" Mappings {{{
nnoremap gb :Git blame<CR>
nnoremap <C-k> :Commentary<CR>j
vnoremap <C-k> :Commentary<CR>
nunmap gcc
vunmap gc
nnoremap <C-w>m :rightbelow vertical terminal<CR>
nnoremap <C-f>f :BLines<CR>
nnoremap <C-f>gg :call ToggleGitFiles()<CR>
nnoremap <C-f>gs :GFiles?<CR>
nnoremap <C-f>aa :Lines<CR>
nnoremap <C-f>af :Rg<CR>
" }}}


" File Type specific Settings {{{

" Settings specifically for vim files
augroup filetype_vim
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker	"set for vim files marker as foldmethod
augroup END

" Settings specifically for python files
augroup filetype_python
    autocmd!
    autocmd FileType python let g:python_recommended_style = 0
augroup END
" }}}

" Include additional config files {{{
" coc.nvim requires atleast vim >= 9.0
if v:version >= 900
    source $HOME/.vim/coc.cfg
endif
" }}}

