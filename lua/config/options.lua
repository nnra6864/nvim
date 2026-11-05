-- Set to false on machines without a Nerd Font
vim.g.have_nerd_font = true

vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.signcolumn = 'yes'
vim.o.showmode = false
vim.o.scrolloff = 10

-- Per-buffer indent is handled in config/indent.lua
vim.o.tabstop = 4
vim.o.shiftwidth = 0
vim.o.softtabstop = -1
vim.o.expandtab = true
vim.o.breakindent = true

vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = 'split'

vim.o.splitright = true
vim.o.splitbelow = true

vim.o.list = true
vim.opt.listchars = { space = '·', tab = '» ', nbsp = '␣' }

vim.o.undofile = true
vim.o.confirm = true
vim.o.updatetime = 250
vim.o.timeoutlen = 300
