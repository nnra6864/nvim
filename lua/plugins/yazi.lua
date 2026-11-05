return {
  'mikavilpas/yazi.nvim',
  version = '*',
  event = 'VeryLazy',
  dependencies = { { 'nvim-lua/plenary.nvim', lazy = true } },
  -- Yazi replaces netrw, so `nvim .` and `:e dir/` open it
  init = function() vim.g.loaded_netrwPlugin = 1 end,
  ---@type YaziConfig | {}
  opts = {
    open_for_directories = true,
    -- <C-s> inside yazi greps the hovered directory or the selected files
    integrations = {
      grep_in_directory = function(dir) Snacks.picker.grep { cwd = dir } end,
      grep_in_selected_files = function(files) Snacks.picker.grep { dirs = files } end,
    },
  },
}
