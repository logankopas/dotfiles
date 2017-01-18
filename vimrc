
" this is a bug that was fixed in vim 7.4
if version < 704
    filetype on
    filetype off
endif
filetype off

let file_ignore_regex = ['\.pyc$', '\.min\.js$']  
let mapleader="\<Space>"

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
let g:ycm_autoclose_preview_window_after_completion=0
let g:ycm_autoclose_preview_window_after_insertion=0
let g:ycm_collect_identifiers_from_tag_files=1
let g:ycm_use_ultisnips_completer = 1
let g:ycm_seed_identifiers_with_syntax = 1
let g:ycm_python_binary_path = 'python'
let g:ycm_auto_start_csharp_server = 1

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

Plug 'tpope/vim-eunuch'

Plug 'vim-scripts/haskell.vim'
Plug 'elixir-lang/vim-elixir'

" fuzzyfinder
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': 'yes \| ./install' }
Plug 'junegunn/fzf.vim'
" fzf mappings
let $FZF_DEFAULT_COMMAND='ag -l -g ""'
noremap <C-b> :Tags<CR>
noremap <C-p> :FZF -m<CR>
set rtp+=~/.fzf

Plug 'scrooloose/syntastic'
let g:syntastic_python_checkers=['flake8']
let g:syntastic_flake8_max_line_length='119'
" let g:syntastic_filetype_map = { 'htmldjango': 'html' }

Plug 'nvie/vim-flake8'
" F7 to run 


Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
" Plug 'Lokaltog/powerline', {'rtp': 'powerline/bindings/vim/'}
" powerline font stuff
let g:airline_powerline_fonts=1
let g:airline#extensions#tabline#enabled=1
let g:airline_theme='bubblegum'
let g:airline#extensions#branch#enabled = 0
set guifont=Inconsolata\ for\ Powerline:h15
set encoding=utf-8
set t_Co=256
set fillchars+=stl:\ ,stlnc:\
set term=xterm-256color
set termencoding=utf-8


Plug 'scrooloose/nerdtree'
Plug 'jistr/vim-nerdtree-tabs'
" ctrl-n to open
" <t> to open in tab
let NERDTreeQuitOnOpen=1
let NERDTreeIgnore = file_ignore_regex
map <C-n> :NERDTreeToggle %<CR>
map <C-n>. :NERDTree %<CR>

"
Plug 'kchmck/vim-coffee-script'
" vim-coffee
let coffee_compiler='/Users/logankopas/work/regiondb/node_modules/coffee-script/bin/coffee'
let coffee_make_options='--map'

Plug 'yssl/QFEnter'
" space-tab to open quickfix in tab

Plug 'sjl/gundo.vim'
" space-z to open gundo tree
nnoremap <leader>z :GundoToggle<CR>


Plug 'rking/ag.vim'
" :Ag for search
nnoremap K :Ag! "\b<C-R><C-W>\b"<CR>:cw<CR>

ca Ag Ag!

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
let test#strategy = "basic"
let g:test#preserve_screen = 1
" run tests easily
nnoremap tt :TestLast<CR>
nnoremap tn :TestNearest<CR>
nnoremap tf :TestFile<CR>


Plug 'terryma/vim-multiple-cursors'
" self explanatory
" because it overwrites ALL of my mappings
let g:multi_cursor_use_default_mapping=0
let g:multi_cursor_next_key='<C-e>'
let g:multi_cursor_prev_key='<C-a>'
let g:multi_cursor_skip_key='<C-x>'
let g:multi_cursor_quit_key='<Esc>'

Plug 'tpope/vim-abolish'
" for comprehensive text substitution

Plug 'tpope/vim-sensible'

Plug 'logan-ncc/vim-buffergator'
" for using buffers instead of tabs
let g:buffergator_suppress_keymaps=1
nnoremap gt :bnext<CR>
nnoremap gT :bprev<CR>
nnoremap <leader>b :BuffergatorToggle<CR>

Plug 'christoomey/vim-tmux-navigator'
Plug 'jceb/vim-orgmode'
nnoremap pp :split ~/todo.org<CR>
Plug 'tpope/vim-speeddating'

Plug 'ChrisPenner/vim-emacs-bindings'
" ctrl-a, ctrl-e, etc

Plug 'junegunn/vim-easy-align'
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

Plug 'mattn/emmet-vim'
" html creation
let g:user_emmet_mode='a'

Plug 'chriskempson/vim-tomorrow-theme'

Plug 'ConradIrwin/vim-bracketed-paste'
" allows you to <c-v> without setting paste

Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
" let's try out snippets for a bit
let g:UltiSnipsExpandTrigger="<C-y>."
let g:UltiSnipsJumpForwardTrigger="<C-y>e"
let g:UltiSnipsJumpBackwardTrigger="<C-y>a"

Plug 'sukima/xmledit'
Plug 'jmcomets/vim-pony'

Plug 'Yggdroot/indentLine'

Plug 'mhinz/vim-startify'
Plug 'junegunn/limelight.vim'
" let g:limelight_conceal_ctermfg = 'gray'
" let g:limelight_conceal_ctermfg = 240
" 
" let g:limelight_conceal_guifg = 'DarkGray'
" let g:limelight_conceal_guifg = '#777777'
let g:limelight_default_coefficient = 0.7

nnoremap <leader>l :Limelight!!<CR>

Plug 'ryanoasis/vim-devicons'

Plug 'godlygeek/tabular'
Plug 'plasticboy/vim-markdown'

Plug 'tpope/vim-fugitive'

Plug 'tweekmonster/django-plus.vim'

Plug 'junkblocker/patchreview-vim'
Plug 'codegram/vim-codereview'

" Prevent jumping outside of current buffer
Plug 'vim-scripts/ingo-library'
Plug 'vim-scripts/EnhancedJumps'
nmap <C-o>         <Plug>EnhancedJumpsLocalOlder
nmap <C-i>         <Plug>EnhancedJumpsLocalNewer
nmap <leader><C-o> <Plug>EnhancedJumpsOlder
nmap <leader><C-i> <Plug>EnhancedJumpsNewer

Plug 'jiangmiao/auto-pairs'
let g:AutoPairsFlyMode = 0
let g:AutoPairsShortcutBackInsert = '∫'  " Alt+B
let g:AutoPairsShortcutFastWrap = '∑'  " Alt+W

call plug#end()
"''''''''''''''''''''''''' End plugins


filetype plugin indent on

" defaults
" set whichwrap+=<,>,h,l,[,]
set hidden  " move off a file without saving
set nu
set tabstop=4
set softtabstop=4
set shiftwidth=4
set textwidth=0
set expandtab
set autoindent
set fileformat=unix  " because screw windows
set laststatus=2  " makes powerline work
set showtabline=2  " always show the tab bar
set noshowmode  " powerline shows us what mode we're in, so vim doesn't have to
set cursorline  " so I don't go searching for my cursor (I still do though)
set wildmenu  " tab completion in commands
set lazyredraw
set ttyfast
set showmatch
set mat=2
set foldenable
set foldlevelstart=99  " all open by default
set wildignore+=*.pyc,*/tmp/*,\.git/*,*.zip,*.gz,*.swp
set tags+=~/.mytags
set relativenumber  " YASSSSSSS
set wrap
set linebreak
set nolist
set breakat=^I!@*-+;:,./?\(\[\{
" * searching in visual mode
vnoremap <silent> * :call VisualSelection('f')<CR> 
vnoremap <silent> # :call VisualSelection('b')<CR>
" pasting in visual mode
xnoremap p pgvy
" because I like white screens
" highlight Visual term=reverse ctermbg=8 guibg=LightGrey
" highlight DiffChange cterm=None ctermfg=LightMagenta ctermbg=LightRed 
" highlight DiffText cterm=None
" Here's a vimdiff to try
" highlight DiffAdd cterm=none ctermfg=fg ctermbg=Blue gui=none guifg=fg guibg=Blue
" highlight DiffDelete cterm=none ctermfg=fg ctermbg=Blue gui=none guifg=fg guibg=Blue
" highlight DiffChange cterm=none ctermfg=fg ctermbg=Blue gui=none guifg=fg guibg=Blue
" highlight DiffText cterm=none ctermfg=bg ctermbg=White gui=none guifg=bg guibg=White
set background=light
colorscheme Tomorrow
set t_ut=

" Persistent undo
set undofile
set undodir=$HOME/.vim/undo

set undolevels=1000
set undoreload=10000

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

" practice not using arrows
nnoremap <Right> :vertical resize +5<CR>
nnoremap <Left> :vertical resize -5<CR>
nnoremap <Up> :resize +5<CR>
nnoremap <Down> :resize -5<CR>

" python files
au BufNewFile,BufRead *.py,*.hs
    \ set tabstop=4
    \ softtabstop=4
    \ shiftwidth=4
    \ textwidth=120
    \ expandtab
    \ autoindent
    \ fileformat=unix
    \ foldmethod=indent
" this is so I can use my testrunners
au BufNewFile,BufRead *.py 
    \ let $DJANGO_SETTINGS_MODULE='deploy_settings.testing'
" web files
au BufNewFile,BufRead *.coffee,*.js,*.html,*.css,*.scss,*.rb,*.yml
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
    \ tabstop=8
    \ softtabstop=0
au FileType org
    \ let maplocalleader='\'
au FileType org
    \ setlocal noautoindent
    \ nocindent
    \ nosmartindent
au FileType gitcommit set tw=120
au BufWritePost,FileWritePost *.tex
    \ Make
au BufWinEnter '__doc__' setlocal bufhidden=delete
au BufWinLeave,WinLeave * setlocal nocursorline
au BufWinEnter,WinEnter * setlocal cursorline

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
iabbrev )L ):

" Delete trailing white space on save, useful for Python and CoffeeScript ;)
func! DeleteTrailingWS()
  exe "normal mz"
  %s/\s\+$//ge
  exe "normal `z"
endfunc
autocmd BufWrite *.py :call DeleteTrailingWS()
autocmd BufWrite *.coffee :call DeleteTrailingWS()

" augroup vimrc_autocmds
"   autocmd BufEnter *.py highlight OverLength ctermbg=darkgrey guibg=#592929
"   autocmd BufEnter *.py match OverLength /\%120v.*/
" augroup END

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
nnoremap <leader>xk :.s/\(.*\)/\=system('a='."https:\/\/api.stackexchange.com\/2.2\/".'; q=`curl -s -G --data-urlencode "q='.submatch(1).'" --compressed "'."${a}search\/advanced?order=desc&sort=relevance&site=stackoverflow".'" \| python -c "'."exec(\\\"import sys \\nimport json\\nprint(json.loads(''.join(sys.stdin.readlines()))['items'][0]['question_id'])\\\")".'"`; curl -s --compressed "'."${a}questions\/$q\/answers?order=desc&sort=votes&site=stackoverflow&filter=withbody".'" \| python -c "'."exec(\\\"import sys\\nimport json\\nprint(json.loads(''.join(sys.stdin.readlines()))['items'][0]['body']).encode('utf8')\\\")".'"')/<CR>

" http://vim.wikia.com/wiki/Deleting_a_buffer_without_closing_the_window
"here is a more exotic version of my original Kwbd script
"delete the buffer; keep windows; create a scratch buffer if no buffers left
function! s:Kwbd(kwbdStage)
  if(a:kwbdStage == 1)
    if(!buflisted(winbufnr(0)))
      bd!
      return
    endif
    let s:kwbdBufNum = bufnr("%")
    let s:kwbdWinNum = winnr()
    windo call s:Kwbd(2)
    execute s:kwbdWinNum . 'wincmd w'
    let s:buflistedLeft = 0
    let s:bufFinalJump = 0
    let l:nBufs = bufnr("$")
    let l:i = 1
    while(l:i <= l:nBufs)
      if(l:i != s:kwbdBufNum)
        if(buflisted(l:i))
          let s:buflistedLeft = s:buflistedLeft + 1
        else
          if(bufexists(l:i) && !strlen(bufname(l:i)) && !s:bufFinalJump)
            let s:bufFinalJump = l:i
          endif
        endif
      endif
      let l:i = l:i + 1
    endwhile
    if(!s:buflistedLeft)
      if(s:bufFinalJump)
        windo if(buflisted(winbufnr(0))) | execute "b! " . s:bufFinalJump | endif
      else
        enew
        let l:newBuf = bufnr("%")
        windo if(buflisted(winbufnr(0))) | execute "b! " . l:newBuf | endif
      endif
      execute s:kwbdWinNum . 'wincmd w'
    endif
    if(buflisted(s:kwbdBufNum) || s:kwbdBufNum == bufnr("%"))
      execute "bd! " . s:kwbdBufNum
    endif
    if(!s:buflistedLeft)
      set buflisted
      set bufhidden=delete
      set buftype=
      setlocal noswapfile
    endif
  else
    if(bufnr("%") == s:kwbdBufNum)
      let prevbufvar = bufnr("#")
      if(prevbufvar > 0 && buflisted(prevbufvar) && prevbufvar != s:kwbdBufNum)
        b #
      else
        bn
      endif
    endif
  endif
endfunction

command! Kwbd call s:Kwbd(1)
nnoremap <silent> <Plug>Kwbd :<C-u>Kwbd<CR>

" debugger
nnoremap bp Oimport pudb; pu.db<C-c>

" Create a mapping (e.g. in your .vimrc) like this:
nmap bd <Plug>Kwbd

inoremap # X<c-h>#
set cinkeys-=0#
set indentkeys-=0#
set incsearch
set nojoinspaces

" Testing envs
function! TestDB(db)
  if(a:db ==? 'm')
    let $TEST_DATABASE='mysql'
  elseif(a:db ==? 'p')
    let $TEST_DATABASE='postgres'
  else
    let $TEST_DATABASE='sqlite'
  endif
endfunction

function! ToggleVerbose()
    if !&verbose
        set verbosefile=~/.log/vim/verbose.log
        set verbose=12
    else
        set verbose=0
        set verbosefile=
    endif
endfunction
