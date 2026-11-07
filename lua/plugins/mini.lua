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
    -- Under gs, since flash uses s: gsa add, gsd delete, gsr replace, gsf/gsF find, gsh highlight
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
      -- Overrides mini.pairs' insert-mode quote mappings (pairs stay registered, so <BS> still deletes both)
      local function smart_quote(q, no_alpha_before)
        return function()
          local line, col = vim.api.nvim_get_current_line(), vim.fn.col '.' - 1
          local before, after = line:sub(1, col), line:sub(col + 1)
          local prev, next = before:sub(-1), after:sub(1, 1)
          if next == q then return MiniPairs.closeopen(q .. q, '..') end
          local _, unescaped = before:gsub('\\.', ''):gsub(vim.pesc(q), '')
          if prev == '\\' or next:match '[%w_]' or unescaped % 2 == 1 or (no_alpha_before and prev:match '%a') then return q end
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
