return {
  'nvim-mini/mini.nvim',
  version = false,
  lazy = false,
  config = function()
    require('mini.icons').setup { style = vim.g.have_nerd_font and 'glyph' or 'ascii' }
    MiniIcons.mock_nvim_web_devicons()

    require('mini.notify').setup()
    vim.notify = MiniNotify.make_notify()

    -- UI
    require('config.statusline').setup()

    local indentscope = require 'mini.indentscope'
    indentscope.setup {
      symbol = '│',
      draw = { delay = 50, animation = indentscope.gen_animation.linear { duration = 60, unit = 'total' } },
    }

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
    require('mini.surround').setup()
    require('mini.align').setup()
    require('mini.pairs').setup()
    require('mini.move').setup()

    -- Git
    require('mini.git').setup()
    require('mini.diff').setup {
      view = { style = 'sign', signs = { add = '+', change = '~', delete = '_' } },
    }
  end,
}
