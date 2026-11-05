-- Indent priority: .editorconfig > what the file already uses (guess-indent) > language default.
-- Width is a single number: shiftwidth=0 follows tabstop and softtabstop=-1 follows shiftwidth,
-- so changing it never leaves the three out of sync (ftplugins like python's set ts=8 sw=4 sts=4).
local M = {}

local spaces = { lua = 2, yaml = 2, dart = 2, typst = 2, json = 2, jsonc = 2 }

function M.set(width, tabs, buf)
  local bo = vim.bo[buf or 0]
  bo.tabstop, bo.shiftwidth, bo.softtabstop = width, 0, -1
  if tabs ~= nil then bo.expandtab = not tabs end
end

function M.toggle_tabs() vim.bo.expandtab = not vim.bo.expandtab end

-- Our FileType autocmd has to run after the ftplugins, so filetype handling is
-- enabled now instead of after init.lua like Neovim does by default
vim.cmd.filetype 'plugin indent on'

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('indent-defaults', { clear = true }),
  callback = function(args)
    local bo = vim.bo[args.buf]
    if spaces[args.match] then
      M.set(spaces[args.match], false, args.buf)
    else
      M.set(bo.shiftwidth > 0 and bo.shiftwidth or bo.tabstop, nil, args.buf)
    end
  end,
})

return M
