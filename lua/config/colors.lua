-- Applies lua/theme.lua (written by Ricer) and re-applies it whenever its contents change.
-- theme.lua returns either a base16 scheme name ('nord') or a palette table.
local M = {}

local dir = vim.fn.stdpath 'config' .. '/lua'
local path = dir .. '/theme.lua'
local applied

-- Ricer exports the terminal palette by name in theme.lua; stock base16 schemes only have
-- base16 slots, mapped the way base16 terminal themes do it
local fallback = {
  black = 'base00', red = 'base08', green = 'base0B', yellow = 'base0A',
  blue = 'base0D', magenta = 'base0E', cyan = 'base0C', white = 'base05',
}
for name, slot in pairs(vim.deepcopy(fallback)) do fallback['br_' .. name] = slot end
fallback.br_black, fallback.br_white = 'base03', 'base07'

--- Hex for a palette name ('blue', 'br_blue'), a base16 key ('base05') or a hex code
function M.get(name)
  if name:sub(1, 1) == '#' then return name end
  local palette = require('base16-colorscheme').colors
  return palette[name] or palette[fallback[name]]
end

-- Applied after every theme load, on top of base16
local function overrides(theme)
  if type(theme) == 'table' and theme.transparent then
    for name in pairs(vim.api.nvim_get_hl(0, {})) do
      if name:find '^BlinkCmp' then vim.cmd.highlight(name .. ' guibg=NONE ctermbg=NONE') end
    end
  end
  for _, group in ipairs { 'PmenuSel', 'BlinkCmpMenuSelection' } do
    vim.api.nvim_set_hl(0, group, { bg = M.get 'blue', bold = true })
  end
end

local transparent_groups = {
  'Normal', 'NormalNC', 'NormalFloat', 'FloatBorder', 'FloatTitle', 'SignColumn', 'LineNr',
  'CursorLine', 'CursorLineNr', 'CursorLineSign', 'EndOfBuffer', 'NonText', 'StatusLine',
  'StatusLineNC', 'WinSeparator', 'Pmenu', 'PmenuSel', 'PmenuSbar', 'PmenuThumb', 'TabLine',
  'TabLineFill', 'TabLineSel', 'TelescopeNormal', 'TelescopeBorder', 'Folded', 'FoldColumn',
}

local function apply()
  local file = io.open(path)
  if not file then
    if not applied then require('base16-colorscheme').setup() end
    return
  end
  local src = file:read '*a'
  file:close()
  if src == applied then return end

  -- Ricer may still be mid-write; a broken or empty file is skipped and the next event retries
  local chunk = load(src, '@' .. path)
  if not chunk then return end
  local ok, theme = pcall(chunk)
  if not ok or (type(theme) ~= 'table' and type(theme) ~= 'string') then return end
  applied = src

  require('base16-colorscheme').setup(theme)
  if type(theme) == 'table' and theme.transparent then
    for _, g in ipairs(transparent_groups) do
      vim.cmd.highlight(g .. ' guibg=NONE ctermbg=NONE')
    end
  end
  overrides(theme)
  -- base16 doesn't fire this itself; the statusline and mini need it to re-derive colors
  vim.api.nvim_exec_autocmds('ColorScheme', { pattern = 'base16' })
end

function M.setup()
  apply()

  local watcher, timer = vim.uv.new_fs_event(), vim.uv.new_timer()
  if not (watcher and timer) then return end
  -- The directory is watched, not the file, because Ricer may replace the file (new inode)
  watcher:start(dir, {}, function(err, name)
    if err or name ~= 'theme.lua' then return end
    timer:start(100, 0, vim.schedule_wrap(apply))
  end)
end

return M
