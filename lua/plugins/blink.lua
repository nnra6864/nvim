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
      -- On list items and quotes, <CR> without a completion continues them (config/lists.lua)
      ['<CR>'] = {
        'accept',
        function()
          if require('config.lists').in_fence_pair() then return vim.keycode '<Cmd>lua require("config.lists").split_fence()<CR>' end
        end,
        function()
          if require('config.lists').handles() then return vim.keycode '<Cmd>lua require("config.lists").newline()<CR>' end
        end,
        'fallback',
      },
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
      per_filetype = {
        lua = { inherit_defaults = true, 'lazydev' },
        markdown = { inherit_defaults = true, 'unresolved_links', 'bible' },
      },
      providers = {
        -- Not inside strings or comments: there snippet prefixes fuzzy-match ordinary words
        -- (a URL in a docker-compose value pulls in multi-line service templates).
        -- Nor in a note's YAML frontmatter, where Markdown snippets crowd out tags.
        snippets = {
          enabled = function()
            local cursor = vim.api.nvim_win_get_cursor(0)
            if vim.bo.filetype == 'markdown' then
              local ok, parser = pcall(vim.treesitter.get_parser, 0)
              local row, col = cursor[1] - 1, cursor[2]
              if ok and parser and parser:language_for_range({ row, col, row, col }):lang() == 'yaml' then return false end
            end
            local ok, node = pcall(vim.treesitter.get_node, { pos = { cursor[1] - 1, math.max(cursor[2] - 1, 0) } })
            while ok and node do
              local type = node:type()
              if type:find 'string' or type:find 'comment' or type:find 'quote_scalar' or type:find 'block_scalar' then return false end
              node = node:parent()
            end
            return true
          end,
        },
        lazydev = { name = 'LazyDev', module = 'lazydev.integrations.blink', score_offset = 100 },
        -- [[links]] to notes that don't exist yet; ranked below existing notes
        unresolved_links = { name = 'Unresolved', module = 'config.unresolved_links', score_offset = -2 },
        -- Bible book names, and verse numbers (with their text) after "Jn 3:"
        bible = { name = 'Bible', module = 'config.bible.blink', score_offset = -3 },
      },
    },

    signature = { enabled = true },
    fuzzy = { implementation = 'prefer_rust_with_warning' },
  },
}
