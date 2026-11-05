local parsers = {
  -- Languages
  'bash', 'c', 'cpp', 'c_sharp', 'dart', 'fish', 'lua', 'luadoc', 'markdown', 'markdown_inline',
  'python', 'typst', 'yaml', 'zig',
  -- Neovim
  'vim', 'vimdoc', 'query',
  -- Misc files you'll end up editing anyway
  'diff', 'gitcommit', 'git_rebase', 'git_config', 'gitignore', 'json', 'toml', 'regex',
}

return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    local ts = require 'nvim-treesitter'
    ts.install(parsers)
    local available = ts.get_available()

    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('treesitter', { clear = true }),
      callback = function(args)
        local buf = args.buf
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang then return end

        local function start()
          if not vim.api.nvim_buf_is_valid(buf) or not pcall(vim.treesitter.start, buf, lang) then return end
          if vim.treesitter.query.get(lang, 'indents') then
            vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end

        if vim.treesitter.language.add(lang) then
          start()
        elseif vim.tbl_contains(available, lang) then
          -- Parser not installed yet: install it and attach once it's compiled
          ts.install(lang):await(start)
        end
      end,
    })
  end,
}
