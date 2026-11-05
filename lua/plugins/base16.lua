return {
  'RRethy/nvim-base16',
  lazy = false,
  priority = 1000,
  config = function() require('config.colors').setup() end,
}
