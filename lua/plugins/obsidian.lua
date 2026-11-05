-- In notes: <CR> follows a link or cycles a checkbox, ]o [o jump between links, and the
-- usual LSP keys work on notes: gd follow link, grr backlinks, grn rename note (updates
-- every link to it), gra note actions (extract, move, merge, insert template, ...)
return {
  'obsidian-nvim/obsidian.nvim',
  version = '*',
  cmd = 'Obsidian',
  -- Loads for Markdown files inside a vault (any folder with .obsidian), never outside one
  init = function()
    vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
      group = vim.api.nvim_create_augroup('obsidian-vault', { clear = true }),
      pattern = '*.md',
      callback = function(ev)
        local vault = require('config.notes').root(ev.match)
        if not vault then return end
        require('config.notes').remember(vault)
        require('lazy').load { plugins = { 'obsidian.nvim' } }
      end,
    })
  end,
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false,
    workspaces = { { name = 'vault', path = function() return require('config.notes').current() end } },
    picker = { name = 'snacks.picker' },
    -- Rendering is left to render-markdown, which also covers Markdown outside vaults
    ui = { enable = false },
    -- Same settings as the Obsidian app, so notes made in either look the same
    note_id_func = function(title) return os.date '%Y-%m-%d %H-%M' .. (title and ' ' .. title or '') end,
    frontmatter = { enabled = false },
    link = { auto_update = true },
    attachments = { folder = 'Assets' },
    templates = { folder = 'Templates', time_format = 'HH:mm:ss' },
  },
}
