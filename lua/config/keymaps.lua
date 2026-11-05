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

-- Completion (the in-menu keys live in plugins/blink.lua)
map('n', '<leader>tg', function()
  vim.g.ghost_text = vim.g.ghost_text == false
  vim.notify('Ghost text ' .. (vim.g.ghost_text and 'on' or 'off'))
end, { desc = 'Toggle ghost text' })
map('n', '<leader>td', function()
  local docs = require('blink.cmp.config').completion.documentation
  docs.auto_show = not docs.auto_show
  vim.notify('Completion docs auto-show ' .. (docs.auto_show and 'on' or 'off'))
end, { desc = 'Toggle completion docs auto-show' })

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

-- LSP. Built in: grn rename, gra code action, grr references, gri implementation,
-- grt type definition, gO document symbols, K hover, <C-s> signature help (insert)
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('lsp-keymaps', { clear = true }),
  callback = function(args)
    local function bmap(lhs, rhs, desc) map('n', lhs, rhs, { buffer = args.buf, desc = desc }) end
    bmap('gd', vim.lsp.buf.definition, 'Go to definition')
    bmap('gD', vim.lsp.buf.declaration, 'Go to declaration')
    bmap('<leader>th', function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = args.buf }, { bufnr = args.buf })
    end, 'Toggle inlay hints')
  end,
})

-- Git
map('n', '<leader>go', function() MiniDiff.toggle_overlay() end, { desc = 'Toggle inline diff' })
map({ 'n', 'x' }, '<leader>gb', function() MiniGit.show_at_cursor() end, { desc = 'Blame/commit at cursor' })
