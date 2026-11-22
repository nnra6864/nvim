-- Leader must be set before lazy.nvim loads any plugin
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

require 'config.options'
require 'config.indent'
require 'config.autocmds'
require 'config.lists'
require 'config.lazy'
-- After plugins: snacks toggles are created as the keymaps are defined
require 'config.keymaps'
require 'config.lsp'
-- The Bible in the vault: :Bible, opening references, cross-reference display (config/bible)
require('config.bible').setup()
