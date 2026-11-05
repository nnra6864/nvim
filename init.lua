-- Leader must be set before lazy.nvim loads any plugin
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

require 'config.options'
require 'config.indent'
require 'config.keymaps'
require 'config.autocmds'
require 'config.lazy'
