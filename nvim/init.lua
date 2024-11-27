-- ####################
-- General Configuration *salutes*
-- ####################

-- Basic Settings
vim.opt.mouse = "a"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.spelllang = "en_gb"
vim.opt.fileformat = "unix"

-- Whitespace Settings
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.joinspaces = false

-- Tab settings
vim.opt.showtabline = 2

-- Search Settings
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Scroll Settings
vim.opt.cursorline = true
vim.opt.cursorcolumn = true
vim.opt.sidescrolloff = 8
vim.opt.scrolloff = 8

-- Line Settings 
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.breakindentopt = { "shift:2", "sbr" }
vim.opt.breakat = "^I!@*-+;:,./?([{"
vim.opt.showbreak = "-->"

-- Display Settings
vim.opt.termguicolors = true
vim.opt.background = "dark"

-- Persist undo
vim.opt.undodir = vim.fn.stdpath("cache") .. "/undo"
vim.opt.undofile = true

-- Split Settings
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Highlight trailing characters
vim.opt.listchars = {
	-- eol = "↲",
	tab = "▸ ",
	trail = "·",
}
vim.opt.list = true

-- Bracket Settings
vim.opt.showmatch = true
vim.opt.matchtime = 2

-- File Settings
vim.opt.wildignore:append({ "*.pyc", "*/tmp/*", ".git/*", "*.zip", "*.gz", "*.swp", "*.orig" })

-- Trial Settings (to see if I like them)

-- System Clipboard
vim.opt.clipboard:append({ "unnamed", "unnamedplus" })

-- Title
vim.opt.title = true -- set the title of window to the value of the titlestring
vim.opt.titlestring = "%<%F%=%l/%L - nvim" -- what the title of the window will be set to

-- ####################
-- Keymap Config
-- ####################

-- TODO hook these up
-- <C-p> goto file
-- <leader>g goto definition
-- <leader>G get doc
-- <leader>u goto references
-- <C-n> filetree
-- K search project for word
-- <leader>a search project 
-- ga easy align
-- <C-o> and <C-i> enhanced jumps

-- Basic Keys
vim.g.mapleader = "<space>"
vim.keymap.set("n", "<leader>ev", ":vsp ~/dotfiles/nvim/init.lua<CR>", 
    { desc = "Open configuration file." })
vim.keymap.set("n", "<leader>sv", ":source ~/dotfiles/nvim/init.lua<CR>", 
    { desc = "Reload configuration file." })

-- Tab/Window Keys
vim.keymap.set("n", "gt", ":bnext<CR>", 
    { desc = "Goto next buffer." })
vim.keymap.set("n", "gT", ":bprev<CR>", 
    { desc = "Goto previous buffer" })
vim.keymap.set("n", "gb", ":e #<CR>", 
    { desc = "Goto last buffer." })
vim.keymap.set("n", "<leader>b", ":bd<CR>", 
    { desc = "Close and delete current buffer." })
vim.keymap.set("n", "<C-k>", ":wincmd k<CR>", 
    { silent = true, desc = "Goto next split window above." })
vim.keymap.set("n", "<C-j>", ":wincmd j<CR>", 
    { silent = true, desc = "Goto next split window below." })
vim.keymap.set("n", "<C-h>", ":wincmd h<CR>", 
    { silent = true, desc = "Goto next split window left." })
vim.keymap.set("n", "<C-l>", ":wincmd l<CR>", 
    { silent = true, desc = "Goto next split window right." })

-- Quick Notes
vim.keymap.set("n", "<leader>pp", ":split ~/todo.org<CR>", 
    { desc = "Open quicknotes file." })

-- Quick line endings
vim.keymap.set("n", "<leader>;", "$a;<Esc>", 
    { desc = "Add a semicolon to EOL." })
vim.keymap.set("n", "<leader><leader>;", "$a:<Esc>", 
    { desc = "Add a colon to EOL." })

-- Pasting in visual mode
vim.keymap.set("x", "p", "pgvy", 
    { desc = "Paste in visual mode without overwriting clipboard." })

-- Navigating with wrap
vim.keymap.set("", "j", "gj")
vim.keymap.set("", "k", "gk")

-- Move text with Command+[jk]
-- TODO these don't work, probably because iterm, I'll figure this out when I switch to Ghostty :)
vim.keymap.set("n", "<M-j>", "mz:m+<CR>`z", 
    { desc = "Move the current line of text down." })
vim.keymap.set("n", "<M-k>", "mz:m-2<CR>`z", 
    { desc = "Move the current line of text up." })
vim.keymap.set("v", "<M-j>", ":m'>+<CR>`<my`mzgv`yo`z", 
    { desc = "Move the current line of text down." })
vim.keymap.set("v", "<M-k>", ":m'<-2<CR>`>my`<mzgv`yo`z", 
    { desc = "Move the current line of text up." })

-- Sub windows 
vim.keymap.set("n", "<leader>p", ":pclose<CR>",
    { desc =  "Close any open preview window."})

-- Terminal
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")

-- ####################
-- TODO section
-- ####################

-- Easy paste
-- Searching in visual mode
-- Toggle quickfix
