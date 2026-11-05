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
map('n', '<leader>n', function() Snacks.picker.notifications() end, { desc = 'Notification history' })
map('n', '<leader>z', function() Snacks.zen() end, { desc = 'Zen mode' })
map('n', '<leader>Z', function() Snacks.zen.zoom() end, { desc = 'Zoom window' })
map({ 'n', 't' }, ']]', function() Snacks.words.jump(vim.v.count1) end, { desc = 'Next reference' })
map({ 'n', 't' }, '[[', function() Snacks.words.jump(-vim.v.count1) end, { desc = 'Previous reference' })

map('n', 'gC', function() require('treesitter-context').go_to_context(vim.v.count1) end, { desc = 'Go to pinned context' })

-- Formatting (when it runs on save is decided in plugins/conform.lua)
map({ 'n', 'x' }, '<leader>f', function() require('conform').format { async = true } end, { desc = 'Format' })

-- Toggles. which-key shows each one's current state
local function toggle(key, name, get, set) Snacks.toggle.new({ id = name, name = name, get = get, set = set }):map(key) end
toggle('<leader>tg', 'Ghost text', function() return vim.g.ghost_text ~= false end, function(on) vim.g.ghost_text = on end)
toggle('<leader>td', 'Completion docs', function() return require('blink.cmp.config').completion.documentation.auto_show end,
  function(on) require('blink.cmp.config').completion.documentation.auto_show = on end)
toggle('<leader>tf', 'Format on save', function() return vim.g.format_on_save ~= false end, function(on) vim.g.format_on_save = on end)
Snacks.toggle.inlay_hints():map '<leader>th'
Snacks.toggle.diagnostics():map '<leader>tx'
Snacks.toggle.option('wrap', { name = 'Wrap' }):map '<leader>tw'
Snacks.toggle.option('spell', { name = 'Spelling' }):map '<leader>ts'
Snacks.toggle.indent():map '<leader>ti'
Snacks.toggle.scroll():map '<leader>tS'
toggle('<leader>tc', 'Pinned context', function() return require('treesitter-context').enabled() end,
  function(on) require('treesitter-context')[on and 'enable' or 'disable']() end)
toggle('<leader>tm', 'Markdown rendering', function() return require('render-markdown').get() end,
  function(on) require('render-markdown').set(on) end)

-- Windows (move them with the built-in <C-w>H/J/K/L; Alt+hjkl moves lines)
map('n', '<leader>|', '<C-w>v', { desc = 'Split vertically' })
map('n', '<leader>-', '<C-w>s', { desc = 'Split horizontally' })
map('n', '<C-h>', '<C-w>h', { desc = 'Focus left' })
map('n', '<C-j>', '<C-w>j', { desc = 'Focus down' })
map('n', '<C-k>', '<C-w>k', { desc = 'Focus up' })
map('n', '<C-l>', '<C-w>l', { desc = 'Focus right' })

-- Files (yazi). Inside yazi: <F1> help, <C-v>/<C-x>/<C-t> open in split/tab, <C-s> grep here,
-- <C-q> selection to quickfix, <C-y> copy relative path
map({ 'n', 'x' }, '<leader>ee', '<cmd>Yazi<CR>', { desc = 'Yazi at current file' })
map('n', '<leader>ew', '<cmd>Yazi cwd<CR>', { desc = 'Yazi in working directory' })
map('n', '<leader>er', '<cmd>Yazi toggle<CR>', { desc = 'Resume last yazi session' })

-- Search (snacks.picker). Inside a picker: <C-j>/<C-k> move, <Tab> mark, <C-q> marked to
-- quickfix, <C-s>/<C-v> open in split, <A-p> toggle preview, <A-h>/<A-i> hidden/ignored files
local pick = function(name, opts)
  return function() Snacks.picker[name](opts) end
end
map('n', '<leader>sf', pick 'files', { desc = 'Files' })
map('n', '<leader>sg', pick 'grep', { desc = 'Grep' })
map({ 'n', 'x' }, '<leader>sw', pick 'grep_word', { desc = 'Word under cursor / selection' })
map('n', '<leader>s/', pick 'grep_buffers', { desc = 'Grep open buffers' })
map('n', '<leader>/', pick 'lines', { desc = 'Lines in this buffer' })
map('n', '<leader><leader>', pick 'buffers', { desc = 'Buffers' })
map('n', '<leader>s.', pick 'recent', { desc = 'Recent files' })
map('n', '<leader>sh', pick 'help', { desc = 'Help' })
map('n', '<leader>sk', pick 'keymaps', { desc = 'Keymaps' })
map('n', '<leader>sc', pick 'commands', { desc = 'Commands' })
map('n', '<leader>sd', pick 'diagnostics', { desc = 'Diagnostics' })
-- Previews live; Esc goes back to the Ricer theme. A picked theme lasts until Ricer writes theme.lua again
map('n', '<leader>st', pick 'colorschemes', { desc = 'Themes' })
map('n', '<leader>sr', pick 'resume', { desc = 'Resume last search' })
map('n', '<leader>sn', pick('files', { cwd = vim.fn.stdpath 'config' }), { desc = 'Neovim config' })
map('n', '<leader>ss', pick 'pickers', { desc = 'All pickers' })
-- Replace (grug-far): in the selection's text, or empty in normal mode; <leader>sF limits it to this file
map('n', '<leader>sR', function() require('grug-far').open() end, { desc = 'Search and replace' })
map('x', '<leader>sR', function() require('grug-far').with_visual_selection() end, { desc = 'Search and replace selection' })
map('n', '<leader>sF', function() require('grug-far').open { prefills = { paths = vim.fn.expand '%' } } end, { desc = 'Search and replace in file' })

-- Notes (obsidian.nvim). Work from anywhere: they use the current vault, or the last one used
local obsidian = function(cmd)
  return function()
    if not require('config.notes').current() then return vim.notify('No Obsidian vault found', vim.log.levels.WARN) end
    vim.cmd('Obsidian ' .. cmd)
  end
end
map('n', '<leader>oo', obsidian 'quick_switch', { desc = 'Find note' })
map('n', '<leader>os', obsidian 'search', { desc = 'Search notes' })
map('n', '<leader>on', function() require('config.notes').new() end, { desc = 'New note' })
map('n', '<leader>ot', function() require('config.notes').new(true) end, { desc = 'New TODO (moves open tasks over)' })
map('n', '<leader>oN', obsidian 'new_from_template', { desc = 'New note from template' })
map('n', '<leader>ob', obsidian 'backlinks', { desc = 'Backlinks' })
map('n', '<leader>ol', obsidian 'links', { desc = 'Links in note' })
map('n', '<leader>og', obsidian 'tags', { desc = 'Tags' })
map('n', '<leader>op', obsidian 'paste_img', { desc = 'Paste image' })
map('n', '<leader>oT', obsidian 'template', { desc = 'Insert template' })

-- Debugging. F-keys while stepping; the view opens with the session
local dap = function(fn, ...)
  local args = { ... }
  return function() require('dap')[fn](unpack(args)) end
end
map('n', '<F5>', dap 'continue', { desc = 'Debug: start/continue' })
map('n', '<F10>', dap 'step_over', { desc = 'Debug: step over' })
map('n', '<F11>', dap 'step_into', { desc = 'Debug: step into' })
map('n', '<F12>', dap 'step_out', { desc = 'Debug: step out' })
map('n', '<leader>dc', dap 'continue', { desc = 'Start/continue' })
map('n', '<leader>db', dap 'toggle_breakpoint', { desc = 'Toggle breakpoint' })
map('n', '<leader>dB', function()
  vim.ui.input({ prompt = 'Condition: ' }, function(cond)
    if cond then require('dap').set_breakpoint(cond) end
  end)
end, { desc = 'Conditional breakpoint' })
map('n', '<leader>dC', dap 'run_to_cursor', { desc = 'Run to cursor' })
map('n', '<leader>dl', dap 'run_last', { desc = 'Rerun last' })
map('n', '<leader>dt', dap 'terminate', { desc = 'Stop' })
-- dap-view is set up when nvim-dap loads, so require that first
local view = function(fn)
  return function()
    require 'dap'
    require('dap-view')[fn]()
  end
end
map({ 'n', 'x' }, '<leader>dw', view 'add_expr', { desc = 'Watch expression' })
map('n', '<leader>dv', view 'toggle', { desc = 'Toggle debug view' })
map({ 'n', 'x' }, '<leader>dh', view 'hover', { desc = 'Value under cursor' })

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
    bmap('gd', pick 'lsp_definitions', 'Go to definition')
    bmap('gD', pick 'lsp_declarations', 'Go to declaration')
    bmap('grr', pick 'lsp_references', 'References')
    bmap('gri', pick 'lsp_implementations', 'Implementations')
    bmap('grt', pick 'lsp_type_definitions', 'Type definition')
    bmap('gO', pick 'lsp_symbols', 'Symbols in file')
    bmap('gW', pick 'lsp_workspace_symbols', 'Symbols in workspace')
  end,
})

-- Typst
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('typst-keymaps', { clear = true }),
  pattern = 'typst',
  callback = function(args)
    map('n', '<leader>tp', '<cmd>TypstPreviewToggle<CR>', { buffer = args.buf, desc = 'Toggle Typst preview' })
  end,
})

-- Git. Hunks (mini.diff): [h ]h jump, gh/gH apply/reset (works with motions, e.g. ghgh).
-- Inside CodeDiff: ]c [c hunks, ]f [f files, t side-by-side/inline, - stage, g? help
-- Repo of the current file, else of the cwd
local function git_root()
  local file = vim.bo.buftype == '' and vim.api.nvim_buf_get_name(0) or ''
  return vim.fs.root(file ~= '' and vim.fs.dirname(file) or vim.fn.getcwd(), '.git')
end
-- CodeDiff reads submodules as files and errors on them, so their paths are left out
local function codediff(...)
  local root = git_root()
  if not root then return vim.notify('Not in a git repository', vim.log.levels.WARN) end
  local args = { '--repo', root, ... }
  local subs = vim.fn.systemlist { 'git', '-C', root, 'config', '--file', '.gitmodules', '--get-regexp', '\\.path$' }
  if vim.v.shell_error == 0 and #subs > 0 then
    vim.list_extend(args, { '--', '.' })
    for _, line in ipairs(subs) do table.insert(args, ':(exclude)' .. line:match '%S+$') end
  end
  vim.cmd.CodeDiff(args)
end
map('n', '<leader>gg', function() Snacks.lazygit() end, { desc = 'Lazygit' })
map('n', '<leader>gd', codediff, { desc = 'Diff changes (and resolve conflicts)' })
map('n', '<leader>gh', '<cmd>CodeDiff history %<CR>', { desc = 'History of this file' })
map('x', '<leader>gh', ':CodeDiff history<CR>', { desc = 'History of these lines' })
map('n', '<leader>gH', '<cmd>CodeDiff history<CR>', { desc = 'History of the repo' })
-- Pick one commit to see its changes, or mark two with <Tab> to diff them against each other
map('n', '<leader>gc', function()
  Snacks.picker.git_log {
    title = 'Commit (mark two with Tab to compare)',
    cwd = git_root(),
    confirm = function(picker)
      local items = picker:selected { fallback = true }
      picker:close()
      -- The log lists newest first, so a higher idx is older
      table.sort(items, function(a, b) return a.idx > b.idx end)
      local old, new = items[1].commit, items[#items].commit
      if old == new then old = new .. '^' end
      codediff(old, new)
    end,
  }
end, { desc = 'Diff commits' })
map({ 'n', 'x' }, '<leader>gB', function() Snacks.gitbrowse() end, { desc = 'Open in browser' })
map({ 'n', 'x' }, '<leader>gY', function()
  Snacks.gitbrowse { open = function(url) vim.fn.setreg('+', url) end, notify = false }
end, { desc = 'Copy browser URL' })
map('n', '<leader>go', function() MiniDiff.toggle_overlay() end, { desc = 'Toggle inline diff' })
map({ 'n', 'x' }, '<leader>gb', function() MiniGit.show_at_cursor() end, { desc = 'Blame/commit at cursor' })
