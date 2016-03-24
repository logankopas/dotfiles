
" this is a bug that was fixed in vim 7.4
if version < 704
    filetype on
    filetype off
endif
filetype off

"''''''''''''''''''''''''' Begin plugins
call plug#begin('~/.vim/plugged')

" Plugins
Plug 'vim-scripts/indentpython.vim'
" YouCompleteMe
if version > 703
    Plug 'Valloric/YouCompleteMe'
endif
" space-g go to definition
" space-G open doc
" space-u tag usages (replaces utags, maybe bring it back?)

Plug 'scrooloose/syntastic'
Plug 'nvie/vim-flake8'
" F7 to run 

Plug 'Lokaltog/powerline', {'rtp': 'powerline/bindings/vim/'}
Plug 'scrooloose/nerdtree'
Plug 'jistr/vim-nerdtree-tabs'
" ctrl-n to open
" <t> to open in tab
"
Plug 'kchmck/vim-coffee-script'
"
Plug 'yssl/QFEnter'
" space-tab to open quickfix in tab

Plug 'sjl/gundo.vim'
" space-z to open gundo tree

Plug 'rking/ag.vim'
" :Ag for search

Plug 'tpope/vim-repeat'
" <.> repeats plugin commands

Plug 'tpope/vim-surround'
" cs, ds, yss
" <command><selection><substitution>
" cs)' -> replace ) with '
" ysiw] -> surround word with []
" yss) -> surround line with ()
" } doesn't add space, { does

Plug 'justinmk/vim-sneak'
" s{character}{character}
" like <f> navigation on steriods

Plug 'tpope/vim-dispatch'
" for running things asynchronously

Plug 'janko-m/vim-test'
" better test runner, lacks quickfix hotlinking

Plug 'terryma/vim-multiple-cursors'
" self explanatory

Plug 'tpope/vim-abolish'
" for comprehensive text substitution

Plug 'jeetsukumaran/vim-buffergator'
" for using buffers instead of tabs
nnoremap gt :bnext<CR>
nnoremap gT :bprev<CR>

Plug 'christoomey/vim-tmux-navigator'
Plug 'jceb/vim-orgmode'
nnoremap pp :split ~/todo.org<CR>
Plug 'tpope/vim-speeddating'

Plug 'mattn/emmet-vim'
" html creation

Plug 'ChrisPenner/vim-emacs-bindings'
" ctrl-a, ctrl-e, etc

" fuzzyfinder
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': 'yes \| ./install' }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-easy-align'
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)
set rtp+=~/.fzf
call plug#end()
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
" pasting in visual mode
xnoremap p pgvy
" because I like white screens
highlight Visual term=reverse ctermbg=8 guibg=LightGrey
highlight DiffChange cterm=None ctermfg=LightMagenta ctermbg=LightRed 
highlight DiffText cterm=None
" Here's a vimdiff to try
" highlight DiffAdd cterm=none ctermfg=fg ctermbg=Blue gui=none guifg=fg guibg=Blue
" highlight DiffDelete cterm=none ctermfg=fg ctermbg=Blue gui=none guifg=fg guibg=Blue
" highlight DiffChange cterm=none ctermfg=fg ctermbg=Blue gui=none guifg=fg guibg=Blue
" highlight DiffText cterm=none ctermfg=bg ctermbg=White gui=none guifg=bg guibg=White

let mapleader="\<Space>"

"''''''''''''''''''''''''' plugin config
" YouCompleteMe
let g:ycm_autoclose_preview_window_after_completion=1
let g:ycm_collect_identifiers_from_tag_files=1
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
let NERDTreeQuitOnOpen=1
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

" TODO get this to work with dispatch
nnoremap K :Ag "\b<C-R><C-W>\b"<CR>:cw<CR>

" vim-coffee
let coffee_compiler='/Users/logankopas/work/regiondb/node_modules/coffee-script/bin/coffee'
let coffee_make_options='--map'

" vim-test
let test#strategy = "dispatch"

" multicursor
" because it overwrites ALL of my mappings
let g:multi_cursor_use_default_mapping=0
let g:multi_cursor_next_key='<C-e>'
let g:multi_cursor_prev_key='<C-a>'
let g:multi_cursor_skip_key='<C-x>'
let g:multi_cursor_quit_key='<Esc>'
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
map <leader>t :tab split<CR>

" edit vimrc and load it
nnoremap <leader>ev :vsp $HOME/dotfiles/vimrc<CR> 
nnoremap <leader>sv :source $HOME/dotfiles/vimrc<CR>

" run tests easily
nnoremap tt :TestLast<CR>
nnoremap tn :TestNearest<CR>

" fzf mappings
noremap <C-b> :Tags<CR>
noremap <C-p> :FZF -m<CR>


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
au BufNewFile,BufRead *.coffee,*.js,*.html,*.css,*.scss,*.rb
    \ set tabstop=2
    \ softtabstop=2
    \ shiftwidth=2
" flag bad whitespace as red
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/
" compile coffeescript on save
au BufWritePost,FileWritePost *.coffee 
    \ silent make -o '%:p:h/../js/'
au FileType make 
    \ set noexpandtab
    \ shiftwidth=8
    \ softtabstop=0
au FileType org
    \ let maplocalleader='\'
au FileType org
    \ setlocal noautoindent
    \ nocindent
    \ nosmartindent
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

" Fix my clumsy fingers
iabbrev impoer import

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

function! s:tags_sink(line)
    let parts = split(a:line, '\t\zs')
    let excmd = matchstr(parts[2:], '^.*\ze;"\t')
    execute 'silent e' parts[1][:-2]
    let [magic, &magic] = [&magic, 0]
    execute excmd
    let &magic = magic
endfunction

function! s:tags()
    if empty(tagfiles())
        echohl WarningMsg
        echom 'Preparing tags'
        echohl None
        call system('ctags -R')
    endif

    call fzf#run({
                \ 'source':  'cat '.join(map(tagfiles(), 'fnamemodify(v:val, ":S")')).
                \            '| grep -v ^!',
                \ 'options': '+m -d "\t" --with-nth 1,4.. -n 1 --tiebreak=index',
                \ 'down':    '40%',
                \ 'sink':    function('s:tags_sink')})
endfunction

command! Tags call s:tags()
command! -nargs=0 -bar Qargs execute 'args' QuickfixFilenames()
function! QuickfixFilenames()
  " Building a hash ensures we get each buffer only once
  let buffer_numbers = {}
  for quickfix_item in getqflist()
    let buffer_numbers[quickfix_item['bufnr']] = bufname(quickfix_item['bufnr'])
  endfor
  return join(map(values(buffer_numbers), 'fnameescape(v:val)'))
endfunction
"''' example usage
" :args *.txt
" :vimgrep /Vimcasts\.\zscom/g ##
" :Qargs
" :argdo %s/Vimcasts\.\zscom/org/ge
" :argdo update

" XKCD jokes
nnoremap xk :.s/\(.*\)/\=system('a='."https:\/\/api.stackexchange.com\/2.2\/".'; q=`curl -s -G --data-urlencode "q='.submatch(1).'" --compressed "'."${a}search\/advanced?order=desc&sort=relevance&site=stackoverflow".'" \| python -c "'."exec(\\\"import sys \\nimport json\\nprint(json.loads(''.join(sys.stdin.readlines()))['items'][0]['question_id'])\\\")".'"`; curl -s --compressed "'."${a}questions\/$q\/answers?order=desc&sort=votes&site=stackoverflow&filter=withbody".'" \| python -c "'."exec(\\\"import sys\\nimport json\\nprint(json.loads(''.join(sys.stdin.readlines()))['items'][0]['body']).encode('utf8')\\\")".'"')/<CR>

