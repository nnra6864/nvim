-- Languages with one official style always format on save. Others only do when the project
-- has its own formatter config, so saving in someone else's repo never reformats whole files.
-- <leader>f formats anything; <leader>tf toggles format on save.
local always = { zig = true, dart = true, fish = true }
local project_configs = {
  lua = { 'stylua.toml', '.stylua.toml' },
  c = { '.clang-format', '_clang-format' },
  cpp = { '.clang-format', '_clang-format' },
  python = { 'pyproject.toml', 'ruff.toml', '.ruff.toml' },
  sh = { '.editorconfig' },
  bash = { '.editorconfig' },
  cs = { '.editorconfig' },
}

return {
  'stevearc/conform.nvim',
  event = 'BufWritePre',
  cmd = 'ConformInfo',
  ---@module 'conform'
  ---@type conform.setupOpts
  opts = {
    -- Filetypes not listed use the language server's formatting (C#, Dart, Typst, YAML, ...)
    formatters_by_ft = {
      lua = { 'stylua' },
      c = { 'clang_format' },
      cpp = { 'clang_format' },
      python = { 'ruff_organize_imports', 'ruff_format' },
      sh = { 'shfmt' },
      bash = { 'shfmt' },
      fish = { 'fish_indent' },
      zig = { 'zigfmt' },
      json = { 'jq' },
    },
    default_format_opts = { lsp_format = 'fallback' },
    notify_on_error = true,
    format_on_save = function(buf)
      if vim.g.format_on_save == false then return end
      local ft = vim.bo[buf].filetype
      local markers = project_configs[ft]
      if always[ft] or (markers and vim.fs.root(buf, markers)) then return { timeout_ms = 1000 } end
    end,
  },
}
