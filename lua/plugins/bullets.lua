return {
  -- Lists continue like in Obsidian: <CR> (insert) and o add the next - / - [ ] / 2. item at the
  -- same indent, <CR> on an empty item removes it, gN renumbers. Insert <CR> is wired through
  -- blink.cmp (plugins/blink.lua), so it still accepts completions first.
  -- > quotes and callouts continue through 'formatoptions' (after/ftplugin/markdown.lua)
  'bullets-vim/bullets.vim',
  ft = { 'markdown', 'text', 'gitcommit' },
  init = function()
    vim.g.bullets_enabled_file_types = { 'markdown', 'text', 'gitcommit' }
    -- Only these keys; its indent keys (>> <C-t> ...) would change - to * when nesting, and
    -- obsidian.nvim's <CR> already toggles checkboxes
    vim.g.bullets_set_mappings = 0
    vim.g.bullets_custom_mappings = {
      { 'nmap', 'o', '<Plug>(bullets-newline)' },
      { 'nmap', 'gN', '<Plug>(bullets-renumber)' },
      { 'vmap', 'gN', '<Plug>(bullets-renumber)' },
    }
    -- A single space after the marker, and no extra indent after a line ending in ':'
    vim.g.bullets_pad_right = 0
    vim.g.bullets_auto_indent_after_colon = 0
  end,
}
