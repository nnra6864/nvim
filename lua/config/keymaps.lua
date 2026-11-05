-- Every keymap we define lives here. Plugin maps call require() inside a function,
-- which makes lazy.nvim load the plugin on first use.
-- Plugins' own default maps (mini.surround's sa/sd/sr, mini.move's Alt+hjkl, ...) are
-- changed in that plugin's config instead.
local map = vim.keymap.set

-- General
map('n', '<Esc>', '<cmd>nohlsearch<CR>')
map({ 'n', 'v' }, '<C-S-c>', '"+y', { desc = 'Copy to clipboard' })
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Diagnostics to loclist' })
map('n', '<leader>n', function() MiniNotify.show_history() end, { desc = 'Notification history' })

-- Windows (move them with the built-in <C-w>H/J/K/L; Alt+hjkl moves lines)
map('n', '<leader>|', '<C-w>v', { desc = 'Split vertically' })
map('n', '<leader>-', '<C-w>s', { desc = 'Split horizontally' })
map('n', '<C-h>', '<C-w>h', { desc = 'Focus left' })
map('n', '<C-j>', '<C-w>j', { desc = 'Focus down' })
map('n', '<C-k>', '<C-w>k', { desc = 'Focus up' })
map('n', '<C-l>', '<C-w>l', { desc = 'Focus right' })

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

-- Git
map('n', '<leader>go', function() MiniDiff.toggle_overlay() end, { desc = 'Toggle inline diff' })
map({ 'n', 'x' }, '<leader>gb', function() MiniGit.show_at_cursor() end, { desc = 'Blame/commit at cursor' })
