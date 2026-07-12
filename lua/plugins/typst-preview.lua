---@module 'lazy'
---@type LazySpec
return {
  'chomosuke/typst-preview.nvim',
  lazy = false, -- or ft = 'typst'
  opts = {}, -- lazy.nvim will implicitly calls `setup {}`
}
