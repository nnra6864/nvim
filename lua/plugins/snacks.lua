-- Forgejo/Gitea URL layout, for gitbrowse
local forgejo = {
  branch = '/src/branch/{branch}',
  file = '/src/branch/{branch}/{file}#L{line_start}-L{line_end}',
  permalink = '/src/commit/{commit}/{file}#L{line_start}-L{line_end}',
  commit = '/commit/{commit}',
}

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
    -- Files over 1.5MB, or with lines averaging 1000+ chars (minified), skip treesitter and LSP
    bigfile = { enabled = true },
    input = { enabled = true },
    notifier = { enabled = true },
    -- Highlights other uses of the symbol under the cursor; ]] [[ jump between them
    words = { enabled = true },
    -- Images inline in Markdown/Typst, and image files opened directly.
    -- The full list is needed to add jxl (lists replace the defaults by position)
    image = {
      enabled = true,
      formats = {
        'png',
        'jpg',
        'jpeg',
        'jxl',
        'gif',
        'bmp',
        'webp',
        'tiff',
        'heic',
        'avif',
        'mp4',
        'mov',
        'avi',
        'mkv',
        'webm',
        'pdf',
        'icns',
      },
    },
    statuscolumn = { enabled = true },
    -- Every view change is animated (<C-d>, gg, searches, zz, ...); mouse wheel is left to the terminal
    scroll = {
      enabled = true,
      animate = { easing = 'outExpo' },
      animate_repeat = { easing = 'outExpo' },
    },
    indent = {
      enabled = true,
      -- Constant speed: `step` ms per line, capped at `total` ms for big scopes
      animate = { duration = { step = 10, total = 200 } },
    },
    -- ii/ai select the current indent scope, [i ]i jump to its edges
    scope = { enabled = true },
    gitbrowse = {
      url_patterns = { ['git%.nnstdios%.com'] = forgejo, ['codeberg%.org'] = forgejo },
    },
  },
}
