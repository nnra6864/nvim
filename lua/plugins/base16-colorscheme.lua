---@module 'lazy'
---@type LazySpec
return {
  'RRethy/nvim-base16',
  lazy = false,
  priority = 1000,
  config = function()
    local base16 = require('base16-colorscheme').with_config({
      telescope = true,
      indentblankline = true,
      notify = true,
      ts_rainbow = true,
      cmp = true,
      illuminate = true,
      dapui = true,
    })
  end,
}
