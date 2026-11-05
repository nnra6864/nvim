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
      -- Takes the ghost text (the first item) without opening the menu
      ['<C-y>'] = { 'select_and_accept', 'fallback' },

      ['<Tab>'] = { 'select_next', 'snippet_forward', 'fallback' },
      ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
      ['<C-j>'] = { 'select_next', 'fallback' },
      ['<C-k>'] = { 'select_prev', 'fallback' },
      ['<Down>'] = { 'select_next', 'fallback' },
      ['<Up>'] = { 'select_prev', 'fallback' },

      ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
      ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
    },

    -- Ghost text and docs auto-show are toggled with <leader>tg / <leader>td
    completion = {
      menu = { auto_show = false },
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
      ghost_text = {
        enabled = function() return vim.g.ghost_text ~= false end,
        show_without_selection = true,
      },
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
