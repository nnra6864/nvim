return {
  -- <leader>j: jump to any visible spot by typing its first chars, then the label shown there.
  -- f/t/F/T are left stock (char mode off): one jump, no labels, ; and , repeat. Keys in config/keymaps.lua
  'folke/flash.nvim',
  event = 'VeryLazy',
  opts = { modes = { char = { enabled = false } } },
}
