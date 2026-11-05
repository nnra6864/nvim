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
      -- Open the menu, then move through it (same keys as in pickers)
      ['<C-j>'] = { 'show', 'select_next', 'fallback' },
      ['<C-k>'] = { 'show', 'select_prev', 'fallback' },
      ['<C-CR>'] = { 'show', 'show_documentation', 'hide_documentation' },
      ['<C-e>'] = { 'hide', 'fallback' },
      ['<CR>'] = { 'accept', 'fallback' },
      -- Takes the ghost text (the first item) without opening the menu
      ['<C-y>'] = { 'select_and_accept', 'fallback' },

      ['<Tab>'] = { 'select_next', 'snippet_forward', 'fallback' },
      ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
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
        -- Off by default in prose: there LSPs offer little, so snippets with plain-word prefixes
        -- ("ordered list", "link", ...) fuzzy-match ordinary words and show up as ghost text.
        -- <leader>tg overrides this per buffer (vim.b.ghost_text).
        enabled = function()
          if vim.b.ghost_text ~= nil then return vim.b.ghost_text end
          local prose = { markdown = true, text = true, gitcommit = true }
          return vim.g.ghost_text ~= false and not prose[vim.bo.filetype]
        end,
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
