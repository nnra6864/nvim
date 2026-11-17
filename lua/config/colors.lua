-- Applies lua/kosm.lua (written by kosm's Neovim app) and re-applies it whenever its contents
-- change. kosm.lua returns one table: the base16 slots, the terminal colors by name ('blue',
-- 'br_blue'), and whether the background is transparent and dark or light.
local M = {}

local dir = vim.fn.stdpath 'config' .. '/lua'
local path = dir .. '/kosm.lua'
local applied

-- Without kosm.lua base16's own default scheme is used, which has only base16 slots; terminal
-- names map to them the way base16 terminal themes do it
local fallback = {
  black = 'base00',
  red = 'base08',
  green = 'base0B',
  yellow = 'base0A',
  blue = 'base0D',
  magenta = 'base0E',
  cyan = 'base0C',
  white = 'base05',
}
for name, slot in pairs(vim.deepcopy(fallback)) do
  fallback['br_' .. name] = slot
end
fallback.br_black, fallback.br_white = 'base03', 'base07'

--- Hex for a palette name ('blue', 'br_blue'), a base16 key ('base05') or a hex code
function M.get(name)
  if name:sub(1, 1) == '#' then return name end
  local palette = require('base16-colorscheme').colors
  return palette[name] or palette[fallback[name]]
end

-- WCAG 2 relative luminance of a hex code, 0..1
local function luminance(hex)
  local total = 0
  for i, weight in ipairs { 0.2126, 0.7152, 0.0722 } do
    local channel = tonumber(hex:sub(2 * i, 2 * i + 1), 16) / 255
    total = total + weight * (channel <= 0.04045 and channel / 12.92 or ((channel + 0.055) / 1.055) ^ 2.4)
  end
  return total
end

local function contrast_ratio(a, b)
  local la, lb = luminance(a), luminance(b)
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

--- Readable text on `background` (a hex code): the palette's black or white, whichever has the
--- higher WCAG contrast ratio, the same pick as kosm's `contrast.on`
function M.on(background)
  local dark, light = M.get 'black', M.get 'white'
  return contrast_ratio(dark, background) >= contrast_ratio(light, background) and dark or light
end

-- Applied after every theme load, on top of base16
local function overrides(theme)
  for _, group in ipairs { 'PmenuSel', 'BlinkCmpMenuSelection', 'BlinkCmpScrollBarThumb', 'SnacksPickerListCursorLine' } do
    vim.api.nvim_set_hl(0, group, { fg = M.on(M.get 'blue'), bg = M.get 'blue', bold = true })
  end
  -- The pinned context is transparent like the code, so a line marks where it ends
  vim.api.nvim_set_hl(0, 'TreesitterContextBottom', { underline = true, sp = M.get 'br_black' })
  vim.api.nvim_set_hl(0, 'TreesitterContextLineNumberBottom', { underline = true, sp = M.get 'br_black' })
end

local transparent_groups = {
  'Normal',
  'NormalNC',
  'NormalFloat',
  'FloatBorder',
  'FloatTitle',
  'SignColumn',
  'LineNr',
  'CursorLine',
  'CursorLineNr',
  'CursorLineSign',
  'EndOfBuffer',
  'NonText',
  'StatusLine',
  'StatusLineNC',
  'WinSeparator',
  'Pmenu',
  'PmenuSel',
  'PmenuSbar',
  'PmenuThumb',
  'TabLine',
  'TabLineFill',
  'TabLineSel',
  'Folded',
  'FoldColumn',
  -- base16 gives the completion windows solid backgrounds
  'BlinkCmpMenu',
  'BlinkCmpMenuBorder',
  'BlinkCmpDoc',
  'BlinkCmpDocBorder',
  'BlinkCmpSignatureHelp',
  'BlinkCmpSignatureHelpBorder',
  'BlinkCmpScrollBarGutter',
}

-- Plugins' fallback groups (set with `default`). Some plugins only define them once at load,
-- so they're saved before any theme clears highlights (ours or another one) and put back after.
local plugin_defaults = {}
local function save_plugin_defaults()
  for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
    if hl.default then plugin_defaults[name] = hl end
  end
end

--- Applies kosm.lua. Skipped when it hasn't changed since the last apply, unless forced
--- (colors/kosm.lua forces it, so `:colorscheme kosm` brings the theme back).
function M.apply(force)
  local file = io.open(path)
  if not file then
    if not applied or force then require('base16-colorscheme').setup() end
    return
  end
  local src = file:read '*a'
  file:close()
  if src == applied and not force then return end

  -- A broken or empty file is skipped and the next change retries
  local chunk = load(src, '@' .. path)
  if not chunk then return end
  local ok, theme = pcall(chunk)
  if not ok or type(theme) ~= 'table' then return end
  applied = src

  -- Plugins pick dark or light colors from 'background'. Setting it reloads the current
  -- colorscheme, so the name is cleared first to keep it from re-entering this function.
  if theme.background and vim.o.background ~= theme.background then
    vim.g.colors_name = nil
    vim.o.background = theme.background
  end

  -- Start from Neovim's defaults so nothing a previously used theme set is left behind
  save_plugin_defaults()
  vim.cmd.highlight 'clear'
  require('base16-colorscheme').setup(theme)
  for name, hl in pairs(plugin_defaults) do
    vim.api.nvim_set_hl(0, name, hl)
  end
  if theme.transparent then
    for _, g in ipairs(transparent_groups) do
      vim.cmd.highlight(g .. ' guibg=NONE ctermbg=NONE')
    end
  end
  overrides(theme)
  -- A real name lets pickers restore this theme after previewing others
  vim.g.colors_name = 'kosm'
  -- base16 doesn't fire this itself; the statusline and mini need it to re-derive colors
  vim.api.nvim_exec_autocmds('ColorScheme', { pattern = 'kosm' })
end

function M.setup()
  M.apply()
  vim.api.nvim_create_autocmd('ColorSchemePre', {
    group = vim.api.nvim_create_augroup('colors', { clear = true }),
    callback = save_plugin_defaults,
  })

  local watcher, timer = vim.uv.new_fs_event(), vim.uv.new_timer()
  if not (watcher and timer) then return end
  -- The directory is watched, not the file, because kosm replaces the file (new inode)
  watcher:start(dir, {}, function(err, name)
    if err or name ~= 'kosm.lua' then return end
    timer:start(100, 0, vim.schedule_wrap(M.apply))
  end)
end

return M
