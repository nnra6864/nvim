return {
  'mikavilpas/yazi.nvim',
  version = '*',
  event = 'VeryLazy',
  dependencies = { { 'nvim-lua/plenary.nvim', lazy = true } },
  ---@type YaziConfig | {}
  opts = {
    -- Directories open in a file picker instead (config/autocmds.lua)
    open_for_directories = false,
    -- <C-s> inside yazi greps the hovered directory or the selected files
    integrations = {
      grep_in_directory = function(dir) Snacks.picker.grep { cwd = dir } end,
      grep_in_selected_files = function(files) Snacks.picker.grep { dirs = files } end,
    },
  },
}
