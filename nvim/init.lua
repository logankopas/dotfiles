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
-- disable netrw in favour of nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

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
-- K search project for word
-- <leader>a search project 
-- ga easy align
-- <C-o> and <C-i> enhanced jumps

-- Basic Keys
vim.g.mapleader = " "
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
vim.keymap.set("n", "<Left>", ":vertical resize -15<CR>",
    { desc = "Decrease window size horizontally." })
vim.keymap.set("n", "<Right>", ":vertical resize +15<CR>",
    { desc = "Increase window size horizontally." })
vim.keymap.set("n", "<Up>", ":resize +15<CR>",
    { desc = "Increase window size vertically." })
vim.keymap.set("n", "<Down>", ":resize -15<CR>",
    { desc = "Decrease window size vertically." })

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
vim.keymap.set("", "j", "gj",
    { silent = true })
vim.keymap.set("", "k", "gk",
    { silent = true })

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


-- ####################
-- Plugin List
-- ####################

local plugins = {
    -- Gruvbox with Treesitter support
    { "ellisonleao/gruvbox.nvim" },

    -- The aforementioned Treesitter
    {
        "nvim-treesitter/nvim-treesitter",
        priority = 1000,
        lazy = false,
        build = ":TSUpdate"
    },
    -- shows the function context at the top of the screen
    { "nvim-treesitter/nvim-treesitter-context" },

    -- Nice indentation
    { "lukas-reineke/indent-blankline.nvim", main = "ibl" },

    -- Commenting
    { 
        "numToStr/Comment.nvim",
        opts = {
            mappings = { extra = false }
        }
    },

    -- Fancy status line
    { 
        "nvim-tree/nvim-web-devicons",
        lazy = true
    },
    { 
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" }
    },

    -- File browser
    { "nvim-tree/nvim-tree.lua" },
    
    -- Better vim-sneak
    { "ggandor/leap.nvim" },

    -- Telescope
    {
        "nvim-telescope/telescope.nvim", tag = "0.1.8",
        dependencies = { "nvim-lua/plenary.nvim" }
    }

}


-- ####################
-- Plugin Installation
-- ####################

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({ 
        "git", "clone", "--filter=blob:none", "--branch=stable", 
        "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup(plugins)


-- ####################
-- Plugin Configuration
-- ####################

vim.cmd("colorscheme gruvbox")

-- Treesitter
require("nvim-treesitter.configs").setup({
    ensure_installed = {
        "arduino",
        "awk",
        "bash",
        "c",
        "css",
        "diff",
        "dockerfile",
        "eex",
        "elixir",
        "html",
        "javascript",
        "jq",
        "json",
        "latex",
        "lua",
        "make",
        "markdown",
        "prolog",
        "python",
        "rust",
        "sql",
        "terraform",
        "vim",
        "vimdoc",
        "yaml",
    },
    sync_install = false,
    auto_install = true,
    highlight = {
        enable = true
    }
})

-- Indentation
require("ibl").setup({
    debounce = 100,

	indent = { char = "▏" },
	whitespace = { highlight = { "Whitespace", "NonText" } },
    scope = {
        show_start = true,
        show_end = false
    }
})

-- Filetree
require("nvim-tree").setup({
    filters = {
        dotfiles = true
    },
    actions = {
        change_dir = { enable = true },

        open_file = { quit_on_open = true }
    }
})

local nvim_tree_api = require("nvim-tree.api")
vim.keymap.set("n", "<C-n>", 
    function()
        nvim_tree_api.tree.toggle({
            find_file = true,
            focus = true
        })
    end
)

-- Lualine
-- bubbles theme
local colors = {
    blue   = '#458588',
    aqua   = '#8ec07c',
    black  = '#282828',
    white  = '#ebdbb2',
    red    = '#cc241d',
    violet = '#b16286',
    grey   = '#928374',
}

local bubbles_theme = {
    normal = {
        a = { fg = colors.black, bg = colors.violet },
        b = { fg = colors.white, bg = colors.grey },
        c = { fg = colors.white },
    },

    insert = { a = { fg = colors.black, bg = colors.blue } },
    visual = { a = { fg = colors.black, bg = colors.aqua } },
    replace = { a = { fg = colors.black, bg = colors.red } },

    inactive = {
        a = { fg = colors.white, bg = colors.black },
        b = { fg = colors.white, bg = colors.black },
        c = { fg = colors.white },
    },
}

require("lualine").setup({
    options = { 
        theme = bubbles_theme,
        component_separators = "",
        section_separators = { left = "", right = "" }
        

    },
    sections = {
        lualine_a = { { "mode", right_padding = 2 } },
        lualine_b = { "filename", "branch" },
        lualine_c = {
            "%=", --[[ add your center compoentnts here in place of this comment ]]
        },
        lualine_x = {},
        lualine_y = { "diff", "filetype", "progress" },
        lualine_z = {
            { "location", left_padding = 2 },
        },
    },
    inactive_sections = {
        lualine_a = { "filename" },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = { "location" },
    },
    tabline = {
        lualine_a = { "buffers" }
    },
    extensions = {},
})

-- Leap
require("leap").add_default_mappings()

-- Telescope
local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, 
    { desc = "Telescope find files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, 
    { desc = "Telescope live grep" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, 
    { desc = "Telescope buffers" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, 
    { desc = "Telescope help tags" })
vim.keymap.set("n", "<leader>ft", builtin.treesitter, 
    { desc = "Telescope treesitter" })
vim.keymap.set("n", "<leader>fp", builtin.planets, 
    { desc = "Telescope planets" })
