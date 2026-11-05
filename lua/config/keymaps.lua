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

-- Indent
local indent = function(...)
  local args = { ... }
  return function() require('config.indent').set(unpack(args)) end
end
map('n', '<leader>i2', indent(2), { desc = 'Indent width 2' })
map('n', '<leader>i4', indent(4), { desc = 'Indent width 4' })
map('n', '<leader>i8', indent(8), { desc = 'Indent width 8' })
map('n', '<leader>it', function() require('config.indent').toggle_tabs() end, { desc = 'Toggle tabs/spaces' })
map('n', '<leader>ig', '<cmd>GuessIndent<CR>', { desc = 'Guess indent from file' })
map('n', '<leader>ir', '<cmd>retab!<CR>', { desc = 'Convert file to current tabs/spaces' })
