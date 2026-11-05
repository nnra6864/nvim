-- Obsidian vaults. obsidian.nvim only runs inside these, and marksman stays out of them,
-- so Markdown anywhere else behaves like plain Markdown.
return {
  { name = 'nn', path = vim.fs.normalize '~/Documents/Obsidian/nn' },
}
