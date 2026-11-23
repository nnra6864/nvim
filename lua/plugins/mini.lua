return {
  'nvim-mini/mini.nvim',
  version = false,
  lazy = false,
  config = function()
    require('mini.icons').setup { style = vim.g.have_nerd_font and 'glyph' or 'ascii' }
    MiniIcons.mock_nvim_web_devicons()

    -- UI
    require('config.statusline').setup()

    local hipatterns = require 'mini.hipatterns'
    local word = function(w, group) return { pattern = '%f[%w]()' .. w .. '()%f[%W]', group = group } end
    hipatterns.setup {
      highlighters = {
        fixme = word('FIXME', 'MiniHipatternsFixme'),
        hack = word('HACK', 'MiniHipatternsHack'),
        todo = word('TODO', 'MiniHipatternsTodo'),
        note = word('NOTE', 'MiniHipatternsNote'),
        hex_color = hipatterns.gen_highlighter.hex_color(),
        -- #RRGGBBAA: the color is shown without its alpha
        hex_alpha = {
          pattern = '#%x%x%x%x%x%x%x%x%f[%X]',
          group = function(_, match) return hipatterns.compute_hex_color_group(match:sub(1, 7), 'bg') end,
        },
      },
    }

    -- Editing
    require('mini.ai').setup { n_lines = 500 }
    -- Under gs, so s stays stock Vim: gsa add, gsd delete, gsr replace, gsf/gsF find, gsh highlight
    require('mini.surround').setup {
      mappings = { add = 'gsa', delete = 'gsd', find = 'gsf', find_left = 'gsF', highlight = 'gsh', replace = 'gsr', update_n_lines = 'gsn' },
    }
    require('mini.align').setup()
    -- Toggle: when true, pairing is context aware (set false for stock mini.pairs).
    -- Brackets: no pair when a word is right after the cursor (|word -> (word).
    -- Quotes/backticks: insert a single one when
    --   - a word is right after the cursor      |a  -> "a
    --   - the line already has an unclosed one  "a| -> "a"
    --   - (' only) a letter is right before     don| -> don't
    -- otherwise pair as usual (a| -> a""). Typing a closer before an existing one jumps over it.
    -- In Markdown, a \ inside `code` is literal, so `\` closes and pairing continues after it,
    -- and ` in an empty span widens it: `|` -> ``|`` -> ```|```.
    -- ``` at the start of a line (after any quote or list marker) opens a code block, ```|```
    -- (<CR> after the language splits it, config/lists.lua), or closes the one already open.
    local smart_pairs = true
    local bracket = smart_pairs and '^[^\\][^%w]' or '^[^\\]'
    require('mini.pairs').setup {
      mappings = {
        ['('] = { action = 'open', pair = '()', neigh_pattern = bracket },
        ['['] = { action = 'open', pair = '[]', neigh_pattern = bracket },
        ['{'] = { action = 'open', pair = '{}', neigh_pattern = bracket },
      },
    }
    if smart_pairs then
      -- Text before a fence's ``` is only a quote, indent and list marker
      local function fence_prefix(s) return s:gsub('^[%s>]*', ''):gsub('^[-*+] ', ''):gsub('^%d+[.)] ', '') == '' end
      local function is_fence(l)
        local prefix = l:match '^(.-)```'
        return prefix ~= nil and fence_prefix(prefix)
      end
      local function in_fenced_block()
        local open = false
        for _, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, vim.fn.line '.' - 1, false)) do
          if is_fence(l) then open = not open end
        end
        return open
      end
      local left = vim.keycode '<C-g>U<Left>'
      -- Markdown code spans: outside them \ escapes, inside a run of N ` closes only on N `
      local function in_code_span(s)
        local i, open = 1, nil
        while i <= #s do
          local c = s:sub(i, i)
          if c == '\\' and not open then
            i = i + 2
          elseif c == '`' then
            local run = #s:match('^`+', i)
            if not open then
              open = run
            elseif run == open then
              open = nil
            end
            i = i + run
          else
            i = i + 1
          end
        end
        return open ~= nil
      end
      -- Overrides mini.pairs' insert-mode quote mappings (pairs stay registered, so <BS> still deletes both)
      local function smart_quote(q, no_alpha_before)
        return function()
          local line, col = vim.api.nvim_get_current_line(), vim.fn.col '.' - 1
          local before, after = line:sub(1, col), line:sub(col + 1)
          local prev, next = before:sub(-1), after:sub(1, 1)
          local markdown = vim.bo.filetype == 'markdown'
          if q == '`' and after == '' and fence_prefix((before:gsub('`*$', ''))) then
            -- The closing fence of an open block: typed as is
            if in_fenced_block() then return q end
            -- Outside Markdown, ` then ` jumps over the pair, so the third one opens the block
            if not markdown and before:match '``$' then return '````' .. left:rep(3) end
          end
          -- Markdown: ` in an empty code span widens it, `|` -> ``|`` -> ```|``` (a code block at line start)
          if q == '`' and markdown then
            local run = #before:match '`*$'
            -- (only an opening run: in ``x`|` the run before the cursor is closing the span)
            if run > 0 and run == #after:match '^`*' and not in_code_span(before:sub(1, -run - 1)) then return '``' .. left end
          end
          if next == q then return MiniPairs.closeopen(q .. q, '..') end
          local unclosed
          if q == '`' and markdown then
            unclosed = in_code_span(before)
          else
            local _, unescaped = before:gsub('\\.', ''):gsub(vim.pesc(q), '')
            unclosed = unescaped % 2 == 1
          end
          if prev == '\\' or next:match '[%w_]' or unclosed or (no_alpha_before and prev:match '%a') then return q end
          return MiniPairs.open(q .. q, '..')
        end
      end
      for q, no_alpha_before in pairs { ['"'] = false, ["'"] = true, ['`'] = false } do
        vim.keymap.set('i', q, smart_quote(q, no_alpha_before), { expr = true, replace_keycodes = false, desc = 'Smart ' .. q })
      end
    end
    require('mini.move').setup()

    -- Git
    require('mini.git').setup()
    require('mini.diff').setup {
      view = { style = 'sign', signs = { add = '+', change = '~', delete = '_' } },
    }
  end,
}
