-- Every keymap lives here. Plugin maps call require() inside a function,
-- which makes lazy.nvim load the plugin on first use.
local map = vim.keymap.set

-- General
map('n', '<Esc>', '<cmd>nohlsearch<CR>')
map({ 'n', 'v' }, '<C-S-c>', '"+y', { desc = 'Copy to clipboard' })
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Diagnostics to loclist' })

-- Windows
map('n', '<leader>|', '<C-w>v', { desc = 'Split vertically' })
map('n', '<leader>-', '<C-w>s', { desc = 'Split horizontally' })

map('n', '<C-h>', '<C-w>h', { desc = 'Focus left' })
map('n', '<C-j>', '<C-w>j', { desc = 'Focus down' })
map('n', '<C-k>', '<C-w>k', { desc = 'Focus up' })
map('n', '<C-l>', '<C-w>l', { desc = 'Focus right' })

map('n', '<A-h>', '<C-w>H', { desc = 'Move window left' })
map('n', '<A-j>', '<C-w>J', { desc = 'Move window down' })
map('n', '<A-k>', '<C-w>K', { desc = 'Move window up' })
map('n', '<A-l>', '<C-w>L', { desc = 'Move window right' })
