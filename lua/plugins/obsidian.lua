local vaults = require 'config.vaults'

-- Loads when a note inside a vault is opened, or on :Obsidian (<leader>o maps) from anywhere
local events = {}
for _, vault in ipairs(vaults) do
  vim.list_extend(events, { 'BufReadPre ' .. vault.path .. '/*.md', 'BufNewFile ' .. vault.path .. '/*.md' })
end

-- In notes: <CR> follows a link or cycles a checkbox, ]o [o jump between links, and the
-- usual LSP keys work on notes: gd follow link, grr backlinks, grn rename note (updates
-- every link to it), gra note actions (extract, move, merge, insert template, ...)
return {
  'obsidian-nvim/obsidian.nvim',
  version = '*',
  event = events,
  cmd = 'Obsidian',
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false,
    workspaces = vaults,
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
