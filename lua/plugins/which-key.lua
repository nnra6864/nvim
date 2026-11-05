return {
  -- Shows available keys after a prefix like <leader> or g
  'folke/which-key.nvim',
  event = 'VeryLazy',
  opts = {
    delay = 0,
    icons = { mappings = vim.g.have_nerd_font },
    spec = {
      { '<leader>s', group = 'Search' },
      { '<leader>t', group = 'Toggle' },
      { '<leader>d', group = 'Debug' },
      { '<leader>e', group = 'Explore' },
      { '<leader>o', group = 'Notes' },
      { '<leader>g', group = 'Git' },
      { '<leader>i', group = 'Indent' },
      { 'gr', group = 'LSP' },
    },
  },
}
