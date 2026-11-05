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
    local statusline = require 'mini.statusline'
    statusline.setup { use_icons = vim.g.have_nerd_font }
    local fileinfo = statusline.section_fileinfo
    ---@diagnostic disable-next-line: duplicate-set-field
    statusline.section_fileinfo = function(args)
      local indent = (vim.bo.expandtab and '␣' or '⇥') .. vim.fn.shiftwidth()
      return indent .. ' ' .. fileinfo(args)
    end

    require('mini.indentscope').setup { symbol = '│' }

    local hipatterns = require 'mini.hipatterns'
    local word = function(w, group) return { pattern = '%f[%w]()' .. w .. '()%f[%W]', group = group } end
    hipatterns.setup {
      highlighters = {
        fixme = word('FIXME', 'MiniHipatternsFixme'),
        hack = word('HACK', 'MiniHipatternsHack'),
        todo = word('TODO', 'MiniHipatternsTodo'),
        note = word('NOTE', 'MiniHipatternsNote'),
        hex_color = hipatterns.gen_highlighter.hex_color(),
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
