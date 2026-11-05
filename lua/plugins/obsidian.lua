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
        local notes = require 'config.notes'
        local vault = notes.root(ev.match)
        if vault then notes.activate(vault) end
      end,
    })
  end,
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false,
    -- The vault being opened; more are added as they're opened (config/notes.lua)
    workspaces = { { path = function() return require('config.notes').current() end } },
    picker = { name = 'snacks.picker' },
    -- Rendering is left to render-markdown, which also covers Markdown outside vaults
    ui = { enable = false },
    -- Same naming as the Obsidian setup; template and attachment folders come from each vault's settings
    note_id_func = function(title) return os.date '%Y-%m-%d %H-%M' .. (title and ' ' .. title or '') end,
    frontmatter = { enabled = false },
    link = { auto_update = true },
  },
}
