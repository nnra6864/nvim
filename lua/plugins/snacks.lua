return {
  -- A collection of small plugins; only the modules configured here are enabled
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    picker = {
      enabled = true,
      ui_select = true,
      -- One <Esc> closes the picker, instead of first leaving insert mode in the prompt
      win = { input = { keys = { ['<Esc>'] = { 'cancel', mode = { 'n', 'i' } } } } },
    },
  },
}
