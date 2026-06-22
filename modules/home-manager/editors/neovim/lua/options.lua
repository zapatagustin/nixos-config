vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.clipboard = "unnamedplus"
opt.undofile = true
opt.swapfile = false
opt.scrolloff = 8
opt.signcolumn = "yes"
opt.wrap = false
opt.splitbelow = true
opt.splitright = true
opt.completeopt = { "menuone", "noselect" }

-- treesitter folding, open by default
opt.foldlevel = 99
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
