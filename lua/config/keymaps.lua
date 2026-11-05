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

-- Search (mini.pick; inside a picker: <C-j>/<C-k> move, <Tab> preview, <C-x> mark,
-- <M-CR> open marked, <C-s>/<C-v> open in split, <C-e> refine)
local pick = function(name, local_opts, opts)
  return function() (MiniPick.builtin[name] or MiniExtra.pickers[name])(local_opts, opts) end
end
map('n', '<leader>sf', pick 'files', { desc = 'Files' })
map('n', '<leader>sg', pick 'grep_live', { desc = 'Grep' })
map('n', '<leader>sw', function() MiniPick.builtin.grep { pattern = vim.fn.expand '<cword>' } end, { desc = 'Word under cursor' })
map('n', '<leader>s/', pick('buf_lines', { scope = 'all' }), { desc = 'Lines in open buffers' })
map('n', '<leader>/', pick('buf_lines', { scope = 'current' }), { desc = 'Lines in this buffer' })
map('n', '<leader><leader>', pick 'buffers', { desc = 'Buffers' })
map('n', '<leader>s.', pick 'oldfiles', { desc = 'Recent files' })
map('n', '<leader>sh', pick 'help', { desc = 'Help' })
map('n', '<leader>sk', pick 'keymaps', { desc = 'Keymaps' })
map('n', '<leader>sc', pick 'commands', { desc = 'Commands' })
map('n', '<leader>so', pick 'options', { desc = 'Options' })
map('n', '<leader>sd', pick 'diagnostic', { desc = 'Diagnostics' })
-- Only lasts until Ricer writes theme.lua again
map('n', '<leader>st', pick 'colorschemes', { desc = 'Themes' })
map('n', '<leader>sr', pick 'resume', { desc = 'Resume last search' })
map('n', '<leader>sn', pick('files', nil, { source = { cwd = vim.fn.stdpath 'config' } }), { desc = 'Neovim config' })
map('n', '<leader>ss', function()
  local names = vim.tbl_keys(MiniPick.registry)
  table.sort(names)
  vim.ui.select(names, { prompt = 'Pickers' }, function(name)
    if name then vim.schedule(MiniPick.registry[name]) end
  end)
end, { desc = 'All pickers' })

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

-- LSP. Built in: grn rename, gra code action, K hover, <C-s> signature help (insert).
-- The jumps below replace the built-in quickfix versions with pickers.
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('lsp-keymaps', { clear = true }),
  callback = function(args)
    local function bmap(lhs, rhs, desc) map('n', lhs, rhs, { buffer = args.buf, desc = desc }) end
    local lsp = function(scope) return pick('lsp', { scope = scope }) end
    bmap('gd', lsp 'definition', 'Go to definition')
    bmap('gD', lsp 'declaration', 'Go to declaration')
    bmap('grr', lsp 'references', 'References')
    bmap('gri', lsp 'implementation', 'Implementations')
    bmap('grt', lsp 'type_definition', 'Type definition')
    bmap('gO', lsp 'document_symbol', 'Symbols in file')
    bmap('gW', lsp 'workspace_symbol_live', 'Symbols in workspace')
    bmap('<leader>th', function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = args.buf }, { bufnr = args.buf })
    end, 'Toggle inlay hints')
  end,
})

-- Git
map('n', '<leader>go', function() MiniDiff.toggle_overlay() end, { desc = 'Toggle inline diff' })
map({ 'n', 'x' }, '<leader>gb', function() MiniGit.show_at_cursor() end, { desc = 'Blame/commit at cursor' })
