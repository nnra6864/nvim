-- mini.statusline layout styled like the oh-my-posh prompt: rounded caps at both ends,
-- arrows and notches chaining the segments, and each segment a step brighter than the
-- previous one (same as Ricer's prompt_bg_hsv_delta).
local M = {}

-- Pick from: red, green, yellow, blue, magenta, cyan, their br_ variants (br_blue, ...),
-- any base16 key ('base05') or a hex code.
-- Re-applied on every theme change.
M.colors = {
  fg = 'base05',
  modes = {
    Normal = 'blue',
    Insert = 'cyan',
    Visual = 'magenta',
    Replace = 'red',
    Command = 'green',
    Other = 'yellow', -- terminal mode and anything else
  },
  -- HSV value added per segment towards the middle, in percent
  step = 10,
  -- HSV value added to the outermost segment, in percent
  offset = -10,
}

-- Ricer exports the named colors in theme.lua; stock base16 schemes only have base16 slots
local fallback = { red = 'base08', yellow = 'base0A', green = 'base0B', cyan = 'base0C', blue = 'base0D', magenta = 'base0E' }
for name, slot in pairs(vim.deepcopy(fallback)) do fallback['br_' .. name] = slot end

local depth = 3 -- segments per side, outermost first

local glyphs = vim.g.have_nerd_font
    and { cap_l = '\u{e0b6}', cap_r = '\u{e0b4}', arrow_r = '\u{e0b0}', arrow_l = '\u{e0b2}', notch_l = '\u{e0d7}', notch_r = '\u{e0d6}' }
  or { cap_l = '', cap_r = '', arrow_r = '', arrow_l = '', notch_l = '', notch_r = '' }

local function color(name)
  if name:sub(1, 1) == '#' then return name end
  local palette = require('base16-colorscheme').colors
  return palette[name] or palette[fallback[name]]
end

-- Scaling all channels by the same factor changes HSV value but keeps hue and saturation
local function brighten(hex, percent)
  local rgb = { tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16) }
  local max = math.max(unpack(rgb))
  if max == 0 then return hex end
  local k = math.max(0, math.min(255, max + percent * 2.55)) / max
  return ('#%02x%02x%02x'):format(rgb[1] * k + 0.5, rgb[2] * k + 0.5, rgb[3] * k + 0.5)
end

function M.highlight()
  -- Separators sit on the statusline's own background, which is NONE when the theme is transparent
  local line_bg = vim.api.nvim_get_hl(0, { name = 'StatusLine', link = false }).bg
  local fg = color(M.colors.fg)
  for mode, key in pairs(M.colors.modes) do
    for i = 1, depth do
      local bg = brighten(color(key), M.colors.offset + (i - 1) * M.colors.step)
      vim.api.nvim_set_hl(0, ('Stl%s%d'):format(mode, i), { fg = fg, bg = bg, bold = i == 1 })
      vim.api.nvim_set_hl(0, ('Stl%s%dSep'):format(mode, i), { fg = bg, bg = line_bg })
    end
  end
end

local function nonempty(list) return vim.tbl_filter(function(s) return s ~= '' end, list) end

-- Renders texts as chained segments; `left` decides which glyphs face which way
local function side(mode, texts, left)
  local out = {}
  for i, text in ipairs(nonempty(texts)) do
    local hl = ('Stl%s%d'):format(mode, i)
    local open = left and (i == 1 and glyphs.cap_l or glyphs.notch_l) or glyphs.arrow_l
    local close = left and glyphs.arrow_r or (i == 1 and glyphs.cap_r or glyphs.notch_r)
    out[#out + 1] = ('%%#%sSep#%s%%#%s# %s %%#%sSep#%s'):format(hl, open, hl, text, hl, close)
  end
  return out
end

function M.active()
  local sl = MiniStatusline
  local mode, mode_hl = sl.section_mode { trunc_width = 120 }
  local name = mode_hl:gsub('^MiniStatuslineMode', '')
  local join = function(...) return table.concat(nonempty { ... }, ' ') end

  local devinfo = join(
    sl.section_git { trunc_width = 40 },
    sl.section_diff { trunc_width = 75 },
    sl.section_diagnostics { trunc_width = 75 },
    sl.section_lsp { trunc_width = 75 }
  )
  local indent = (vim.bo.expandtab and '␣' or '⇥') .. vim.fn.shiftwidth()
  local fileinfo = join(indent, sl.section_fileinfo { trunc_width = 120 })
  local position = join(sl.section_searchcount { trunc_width = 75 }, sl.section_location { trunc_width = 75 })

  local left = side(name, { mode, devinfo, sl.section_filename { trunc_width = 140 } }, true)
  local right = side(name, { position, fileinfo }, false)
  -- Truncate the filename first when the window is narrow
  left[#left] = '%<' .. left[#left]
  return table.concat(left) .. '%#StatusLine#%=' .. table.concat(vim.fn.reverse(right))
end

function M.setup()
  require('mini.statusline').setup {
    use_icons = vim.g.have_nerd_font,
    content = { active = M.active },
  }
  M.highlight()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('statusline', { clear = true }),
    callback = M.highlight,
  })
end

return M
