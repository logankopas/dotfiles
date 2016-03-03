set nocompatible
" this is a bug that was fixed in vim 7.4
if version < 704
    filetype on
    filetype off
endif
filetype off

"''''''''''''''''''''''''' Begin plugins
" Include vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" This one is required for vundle
Plugin 'gmarik/Vundle.vim'

" Plugins
Plugin 'vim-scripts/indentpython.vim'
" YouCompleteMe
if version > 703
    Bundle 'Valloric/YouCompleteMe'
endif
" space-g go to definition
" space-G open doc
" space-u tag usages (replaces utags, maybe bring it back?)

Plugin 'scrooloose/syntastic'
Plugin 'nvie/vim-flake8'
" F7 to run 
Plugin 'kien/ctrlp.vim'
" ctrl-p to file search
" ctrl-m to tag search
" ctrl-t to open in tab

Bundle 'Lokaltog/powerline', {'rtp': 'powerline/bindings/vim/'}
Plugin 'scrooloose/nerdtree'
" ctrl-n to open
" <t> to open in tab
Plugin 'jistr/vim-nerdtree-tabs'
Plugin 'kchmck/vim-coffee-script'
Plugin 'JarrodCTaylor/vim-python-test-runner'
" :DjangoTestApp seems to be the only one that works
" TODO fork this and make it work for the general case, 
" TODO along with specifying arbitrary django tests
Plugin 'FelikZ/ctrlp-py-matcher'
" speeds up ctrlp
Plugin 'yssl/QFEnter'
" space-tab to open quickfix in tab
Plugin 'sjl/gundo.vim'
" space-z to open gundo tree
Plugin 'rking/ag.vim'
" :Ag for search
Plugin 'tpope/vim-repeat'
" <.> repeats plugin commands
Plugin 'tpope/vim-surround'
" cs, ds, yss
" <command><selection><substitution>
" cs)' -> replace ) with '
" ysiw] -> surround word with []
" yss) -> surround line with ()
" } doesn't add space, { does

Plugin 'justinmk/vim-sneak'
" s{character}{character}
" like <f> navigation on steriods

call vundle#end()
"''''''''''''''''''''''''' End plugins


filetype plugin indent on

" defaults
" set whichwrap+=<,>,h,l,[,]
set nu
set tabstop=4
set softtabstop=4
set shiftwidth=4
set textwidth=139
set expandtab
set autoindent
set fileformat=unix  " because screw windows
set laststatus=2  " makes powerline work
set showtabline=2  " always show the tab bar
set noshowmode  " powerline shows us what mode we're in, so vim doesn't have to
set cursorline  " so I don't go searching for my cursor (I still do though)
set wildmenu  " tab completion in commands
set lazyredraw
set showmatch
set mat=2
set foldenable
set foldlevelstart=99  " all open by default
set wildignore+=*.pyc,*/tmp/*,\.git/*,*.zip,*.gz,*.swp
set tags+=~/.mytags
set relativenumber  " YASSSSSSS
" * searching in visual mode
vnoremap <silent> * :call VisualSelection('f')<CR> 
vnoremap <silent> # :call VisualSelection('b')<CR>
" because I like white screens
hi Visual term=reverse ctermbg=8 guibg=LightGrey

let mapleader="\<Space>"

"''''''''''''''''''''''''' plugin config
" YouCompleteMe
let g:ycm_autoclose_preview_window_after_completion=1
map <leader>g  :YcmCompleter GoToDefinitionElseDeclaration<CR>
map <leader>G  :YcmCompleter GetDoc<CR>
map <leader>u  :YcmCompleter GoToReferences<CR>
" python support for youcompleteme
" python with virtualenv support
py << EOF
import os
import sys
if 'VIRTUAL_ENV' in os.environ:
    project_base_dir = os.environ['VIRTUAL_ENV']
    activate_this = os.path.join(project_base_dir, 'bin/activate_this.py')
    execfile(activate_this, dict(__file__=activate_this))
EOF
let python_highlight_all=1

" NERDTree
map <C-n> :NERDTreeToggle %<CR>

" powerline font stuff
set guifont=Inconsolata\ for\ Powerline:h15
let g:Powerline_symbols = 'fancy'
set encoding=utf-8
set t_Co=256
set fillchars+=stl:\ ,stlnc:\
set term=xterm-256color
set termencoding=utf-8

" syntastic
let g:syntastic_python_checkers=['flake8']
let g:syntastic_flake8_max_line_length='139'

" gundo
nnoremap <leader>z :GundoToggle<CR>

" ctrlp
map <C-m> :CtrlPTag<CR>
let g:ctrlp_cache_dir = $HOME . '/.cache/ctrlp'
if executable('ag')
    let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'
endif
let g:ctrlp_match_func = { 'match': 'pymatcher#PyMatch' }

" vim-coffee
let coffee_compiler='/Users/logankopas/work/regiondb/node_modules/coffee-script/bin/coffee'
let coffee_make_options='--map'
"''''''''''''''''''''''''' end plugin config

syntax on
highlight BadWhitespace ctermbg=red guibg=darkred

nnoremap <leader>s :mksession<CR>
map j gj
map k gk
" Move a line of text using ALT+[jk] or Comamnd+[jk] on mac
nmap <M-j> mz:m+<cr>`z
nmap <M-k> mz:m-2<cr>`z
vmap <M-j> :m'>+<cr>`<my`>mzgv`yo`z
vmap <M-k> :m'<-2<cr>`>my`<mzgv`yo`z
if has("mac") || has("macunix")
  nmap <D-j> <M-j>
  nmap <D-k> <M-k>
  vmap <D-j> <M-j>
  vmap <D-k> <M-k>
endif

" edit vimrc and load it
nnoremap <leader>ev :vsp $HOME/dotfiles/vimrc<CR> 
nnoremap <leader>sv :source $HOME/dotfiles/vimrc<CR>


" python files
au BufNewFile,BufRead *.py
    \ set tabstop=4
    \ softtabstop=4
    \ shiftwidth=4
    \ textwidth=139
    \ expandtab
    \ autoindent
    \ fileformat=unix
    \ foldmethod=indent
" this is so I can use my testrunners
au BufNewFile,BufRead *.py 
    \ let $DJANGO_SETTINGS_MODULE='deploy_settings.testing'
" web files
au BufNewFile,BufRead *.coffee,*.js,*.html,*.css,*.scss
    \ set tabstop=2
    \ softtabstop=2
    \ shiftwidth=2
" flag bad whitespace as red
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/
" compile coffeescript on save
au BufWritePost,FileWritePost *.coffee 
    \ silent make -o '%:p:h/../js/'
" set the current file to the working directory
" au BufEnter * lcd %:p:h

" function to toggle relativenumber
function! ToggleNumber()
    if(&relativenumber == 1)
        set norelativenumber
        set number
    else
        set relativenumber
    endif
endfunc

nnoremap <leader>n :call ToggleNumber()<CR>

nnoremap <leader>c :cclose<CR>
nnoremap <leader>p :pclose<CR>

" testing this
" Delete trailing white space on save, useful for Python and CoffeeScript ;)
func! DeleteTrailingWS()
  exe "normal mz"
  %s/\s\+$//ge
  exe "normal `z"
endfunc
autocmd BufWrite *.py :call DeleteTrailingWS()
autocmd BufWrite *.coffee :call DeleteTrailingWS()

function! CmdLine(str)
    exe "menu Foo.Bar :" . a:str
    emenu Foo.Bar
    unmenu Foo
endfunction
function! VisualSelection(direction) range
    let l:saved_reg = @"
    execute "normal! vgvy"

    let l:pattern = escape(@", '\\/.*$^~[]')
    let l:pattern = substitute(l:pattern, "\n$", "", "")

    if a:direction == 'b'
        execute "normal ?" . l:pattern . "^M"
    elseif a:direction == 'gv'
        call CmdLine("vimgrep " . '/'. l:pattern . '/' . ' **/*.')
    elseif a:direction == 'replace'
        call CmdLine("%s" . '/'. l:pattern . '/')
    elseif a:direction == 'f'
        execute "normal /" . l:pattern . "^M"
    endif

    let @/ = l:pattern
    let @" = l:saved_reg
endfunction
" When you press gv you vimgrep after the selected text
vnoremap <silent> gv :call VisualSelection('gv')<CR>
" When you press <leader>r you can search and replace the selected text
vnoremap <silent> <leader>r :call VisualSelection('replace')<CR>

" TODO look at setting up fzf
