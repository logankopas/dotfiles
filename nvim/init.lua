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

-- Diagnostics
vim.keymap.set("n", "<leader>ee", vim.diagnostic.open_float,
    { desc = "Open diagnostic window." })


-- Terminal
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")


-- ####################
-- TODO section
-- ####################

-- Easy paste
-- Searching in visual mode
-- Toggle quickfix
--
-- These plugins were lost when my init file was lost. Maybe add them back
--  cmp-nvim-lsp
--  mason-lspconfig.nvim
--  mason-null-ls.nvim
--  mason.nvim
--  none-ls.nvim
--  nvim-cmp
--  nvim-lspconfig
--  nvim-surround
--  nvim-ts-autotag
--  trouble.nvim
--  ultimate-autopair.nvim
--  vim-emacs-bindings
--  vim-python-pep8-indent
--  which-key.nvim


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
    
    -- Another motion plugin
    { "ChrisPenner/vim-emacs-bindings" },

    -- Telescope
    {
        "nvim-telescope/telescope.nvim", tag = "0.1.8",
        dependencies = { "nvim-lua/plenary.nvim" }
    },

    -- Surround things (brackets, quotes, tags, etc)
    {
        "kylechui/nvim-surround",
        version = "*",
        event = "VeryLazy",
        config = function()
            require("nvim-surround").setup({})
        end
    },
    {
        "windwp/nvim-ts-autotag",
        config = function()
            require("nvim-ts-autotag").setup({})
    	end
    },
    {
        'altermo/ultimate-autopair.nvim',
        event={'InsertEnter','CmdlineEnter'},
        branch='v0.6',
        config = function()
            require("ultimate-autopair").setup({})
        end

    },

    -- Help me remember my keys!
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            -- your configuration comes here
            -- or leave it empty to use the default settings
            -- refer to the configuration section below
        },
        keys = {
            {
                "<leader>?",
                function()
                    require("which-key").show({ global = false })
                end,
                desc = "Buffer Local Keymaps (which-key)",
            },
        },
    },

    -- LSP stuff
    {
        "VonHeikemen/lsp-zero.nvim",
        branch = "v4.x",
        dependencies = {
            -- LSP Support
            { "neovim/nvim-lspconfig" },
            {
                "williamboman/mason.nvim",
                build = function()
                    pcall(vim.cmd, "MasonUpdate")
                end,
            },
            { "williamboman/mason-lspconfig.nvim" },

            -- Autocompletion
            { "hrsh7th/nvim-cmp" },
            { "hrsh7th/cmp-nvim-lsp" },
            { "hrsh7th/cmp-path" },
            { "L3MON4D3/LuaSnip" },
            { "hrsh7th/cmp-buffer" },
            { "hrsh7th/cmp-nvim-lsp-signature-help" },
        },
    },

    -- None-LS
    { "nvimtools/none-ls.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
    { "jay-babu/mason-null-ls.nvim" },

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
vim.keymap.set("n", "<leader>fq", builtin.quickfix, 
    { desc = "Telescope quickfix" })
vim.keymap.set("n", "<leader>fl", builtin.loclist, 
    { desc = "Telescope loclist" })
vim.keymap.set("n", "<leader>fd", builtin.diagnostics, 
    { desc = "Telescope diagnostics" })


-- ####################
-- LSP Section
-- ####################

-- Copied and modified from carderne/dotfiles
local cmp = require("cmp")
local cmp_format = require("lsp-zero").cmp_format()
cmp.setup({
    formatting = cmp_format,
    snippet = {
        expand = function(args)
            require("luasnip").lsp_expand(args.body)
        end,
    },
    sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "nvim_lsp_signature_help" },
        { name = "path", max_item_count = 6 },
    }, {
        { name = "buffer" },
    }),
    preselect = "item",
    completion = {
        completeopt = "menu,menuone,noinsert",
    },
    mapping = cmp.mapping.preset.insert({
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm({ select = false }),
        ["<Tab>"] = cmp.mapping.confirm({select = true}),
        ["<C-k>"] = cmp.mapping.select_prev_item({ behavior = "insert" }),
        ["<C-j>"] = cmp.mapping.select_next_item({ behavior = "insert" }), -- or select
    }),
})

local lsp_zero = require("lsp-zero")
local lsp_attach = function(client, bufnr)
    local opts = { buffer = bufnr }
    lsp_zero.default_keymaps(opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    -- nnoremap <silent> ca <cmd>lua vim.lsp.buf.code_action()<CR>
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "gd", builtin.lsp_definitions, opts)
    vim.keymap.set("n", "gr", builtin.lsp_references, opts)

    -- Disable semantic highlights
    client.server_capabilities.semanticTokensProvider = nil
end
lsp_zero.extend_lspconfig({
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
    lsp_attach = lsp_attach,
    float_border = "rounded",
    sign_text = true,
})

require("mason").setup({})
require("mason-lspconfig").setup({
    -- https://github.com/williamboman/mason-lspconfig.nvim#available-lsp-servers
    ensure_installed = {
        -- "tsserver",
        -- "ts_ls",
        -- "basedpyright",
        -- "pyright",
        "ruff",
        -- "eslint",
        -- "bashls",
        -- "beancount",
        -- "cssls",
        -- "dockerls",
        -- "docker_compose_language_service",
        -- "gopls",
        -- "html",
        -- "jsonls",
        -- "lua_ls",
        "rust_analyzer@2024-10-14",
        -- "sqlls",
        -- "terraformls",
        -- "yamlls",
        -- "pest_ls",
    },
    handlers = {
        lsp_zero.default_setup,
    },
})
-- require("mason-lspconfig").setup_handlers({
--     function(server_name) -- default handler (optional)
--         -- https://github.com/neovim/nvim-lspconfig/pull/3232
--         server_name = server_name == 'tsserver' and 'ts_ls' or server_name
--         local capabilities = require("cmp_nvim_lsp").default_capabilities()
--         require("lspconfig")[server_name].setup({
--             capabilities = capabilities,
--         })
--     end,
-- })

require("lspconfig").rust_analyzer.setup({
    settings = {
        ["rust-analyzer"] = {
            cargo = {
                allFeatures = true,
            },
            diagnostic = {
                enabled = false
            }
        },
    },
})

lsp_zero.format_mapping("<leader>fo", {
    format_opts = {
        async = true,
        timeout_ms = 10000,
    },
    servers = {
        -- ["null-ls"] = { "javascript", "typescript", "lua", "go", "json", "typescriptreact" },
        ["rust_analyzer"] = { "rust" },
        ["ruff"] = { "python" },
    },
})

local null_ls = require("null-ls")
null_ls.setup({
    sources = {
        null_ls.builtins.formatting.prettier,
        null_ls.builtins.formatting.stylua,
        -- null_ls.builtins.formatting.jq,
        null_ls.builtins.formatting.gofmt,
        -- null_ls.builtins.formatting.ruff,
    },
})
require("mason-null-ls").setup({
    ensure_installed = nil,
    automatic_installation = true,
})

vim.diagnostic.config({
    virtual_text = false,
    signs = true,
    update_in_insert = false,
    underline = true,
})
