" VSCode neovim config

" basic settings
let mapleader="\<Space>"
set relativenumber

" tab navigation
nmap gt :tabn<CR>
nmap gT :tabp<CR>
nmap gb :tablast<CR>
nmap <leader>b :bd<CR>
nmap <leader>t :tabn<CR>

" plugin section
nnoremap <silent> <Space> :call VSCodeNotify('whichkey.show')<CR>
xnoremap <silent> <Space> :call VSCodeNotify('whichkey.show')<CR>
