-- Applies lua/kosm.lua (written by kosm's Neovim app) and re-applies it whenever its contents
-- change. kosm.lua returns one table: `background` ('dark' or 'light'), `highlights` (every
-- group by name, as nvim_set_hl takes it) and `terminal` (the terminal colors by name: 'blue',
-- 'br_blue').
local M = {}

local dir = vim.fn.stdpath 'config' .. '/lua'
local path = dir .. '/kosm.lua'
local applied
local terminal = {}

-- Without kosm.lua Neovim's default colorscheme is used, so names map to its colors
local defaults = {
  black = 'NvimDarkGrey2',
  red = 'NvimLightRed',
  green = 'NvimLightGreen',
  yellow = 'NvimLightYellow',
  blue = 'NvimLightBlue',
  magenta = 'NvimLightMagenta',
  cyan = 'NvimLightCyan',
  white = 'NvimLightGrey2',
}
for name, color in pairs(vim.deepcopy(defaults)) do
  defaults['br_' .. name] = color
end
defaults.br_black, defaults.br_white = 'NvimDarkGrey4', 'NvimLightGrey1'

-- Terminal colors 0..15 in order
local terminal_names = { 'black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white' }
for i = 1, 8 do
  terminal_names[i + 8] = 'br_' .. terminal_names[i]
end

--- Hex for a terminal color name ('blue', 'br_blue') or a hex code
function M.get(name)
  if name:sub(1, 1) == '#' then return name end
  if terminal[name] then return terminal[name] end
  return ('#%06x'):format(vim.api.nvim_get_color_by_name(defaults[name]))
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

-- Plugin groups kosm doesn't write, applied after every theme load
local function overrides()
  -- The focused picker's cursor line stands out like the completion menu's selection
  vim.api.nvim_set_hl(0, 'SnacksPickerListCursorLine', { link = 'PmenuSel' })
  -- The pinned context is transparent like the code, so a line marks where it ends
  vim.api.nvim_set_hl(0, 'TreesitterContextBottom', { underline = true, sp = M.get 'br_black' })
  vim.api.nvim_set_hl(0, 'TreesitterContextLineNumberBottom', { underline = true, sp = M.get 'br_black' })
end

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
    if not applied or force then
      terminal = {}
      vim.cmd.colorscheme 'default'
    end
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
  terminal = theme.terminal or {}

  -- Plugins pick dark or light colors from 'background'. Setting it reloads the current
  -- colorscheme, so the name is cleared first to keep it from re-entering this function.
  if theme.background and vim.o.background ~= theme.background then
    vim.g.colors_name = nil
    vim.o.background = theme.background
  end

  -- Start from Neovim's defaults so nothing a previously used theme set is left behind
  save_plugin_defaults()
  vim.cmd.highlight 'clear'
  for name, hl in pairs(plugin_defaults) do
    vim.api.nvim_set_hl(0, name, hl)
  end
  for name, hl in pairs(theme.highlights or {}) do
    vim.api.nvim_set_hl(0, name, hl)
  end
  for i, name in ipairs(terminal_names) do
    vim.g['terminal_color_' .. (i - 1)] = terminal[name]
  end
  overrides()
  -- A real name lets pickers restore this theme after previewing others
  vim.g.colors_name = 'kosm'
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
