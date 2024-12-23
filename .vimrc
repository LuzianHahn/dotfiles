" Plugins {{{
packadd vim-fugitive
packadd vim-commentary
packadd ale
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

set omnifunc=ale#completion#OmniFunc
let g:ale_completion_enabled = 1            " activate Ale's own completion mechanism
let g:ale_linters = {
\ 'rust': ['analyzer'],
\ 'python': ['jedils'],
\ }
" }}}

" Functions {{{
function! Auto_complete_string()
    if pumvisible()
        return "\<C-n>"
    else
        return "\<C-x>\<C-o>\<C-r>=Auto_complete_opened()\<CR>"
    end
endfunction

function! Auto_complete_opened()
    if pumvisible()
        return "\<Down>"
    end
    return ""
endfunction
" }}}

" Mappings {{{
nnoremap gb :Git blame<CR>
nnoremap <C-k> :Commentary<CR>j
vnoremap <C-k> :Commentary<CR>
nunmap gcc
vunmap gc
nnoremap <C-w>m :rightbelow vertical terminal<CR>
" Solution taken from https://stackoverflow.com/questions/510503/ctrlspace-for-omni-and-keyword-completion-in-vim
inoremap <expr> <Nul> Auto_complete_string()
inoremap <expr> <C-Space> Auto_complete_string()
nnoremap <C-w>g :ALEGoToDefinition<CR>
nnoremap <C-w>k :ALEHover<CR>
nnoremap <C-w>f :ALEFindReferences<CR>
nnoremap <C-w>r :ALERename<CR>
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
