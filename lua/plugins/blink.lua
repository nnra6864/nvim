return {
  'saghen/blink.cmp',
  version = '1.*',
  -- Not lazy: it registers its LSP capabilities when loaded, and servers started before that miss them
  lazy = false,
  dependencies = { 'rafamadriz/friendly-snippets' },
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    keymap = {
      preset = 'none',
      ['<C-CR>'] = { 'show', 'show_documentation', 'hide_documentation' },
      ['<C-e>'] = { 'hide', 'fallback' },
      ['<CR>'] = { 'accept', 'fallback' },

      ['<Tab>'] = { 'select_next', 'snippet_forward', 'fallback' },
      ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
      ['<C-j>'] = { 'select_next', 'fallback' },
      ['<C-k>'] = { 'select_prev', 'fallback' },
      ['<Down>'] = { 'select_next', 'fallback' },
      ['<Up>'] = { 'select_prev', 'fallback' },

      ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
      ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
    },

    completion = {
      menu = { auto_show = false },
      documentation = { auto_show = false },
    },

    sources = {
      default = { 'lsp', 'path', 'snippets' },
      per_filetype = { lua = { inherit_defaults = true, 'lazydev' } },
      providers = {
        lazydev = { name = 'LazyDev', module = 'lazydev.integrations.blink', score_offset = 100 },
      },
    },

    signature = { enabled = true },
    fuzzy = { implementation = 'prefer_rust_with_warning' },
  },
}
