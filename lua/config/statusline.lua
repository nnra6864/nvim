-- mini.statusline layout styled like the oh-my-posh prompt: a rounded cap at both ends,
-- with arrows and notches chaining the segments together.
local M = {}

-- { fg, bg } as base16 keys ('base0D') or hex ('#267180'). Re-applied on every theme change.
M.colors = {
  Normal = { 'base05', 'base0D' },
  Insert = { 'base05', 'base0B' },
  Visual = { 'base05', 'base0E' },
  Replace = { 'base05', 'base08' },
  Command = { 'base05', 'base0A' },
  Other = { 'base05', 'base0C' },
  Info = { 'base05', 'base02' },
}

local glyphs = vim.g.have_nerd_font
    and { cap_l = '\u{e0b6}', cap_r = '\u{e0b4}', arrow_r = '\u{e0b0}', arrow_l = '\u{e0b2}', notch_l = '\u{e0d7}', notch_r = '\u{e0d6}' }
  or { cap_l = '', cap_r = '', arrow_r = '', arrow_l = '', notch_l = '', notch_r = '' }

local function resolve(c) return c:match '^base' and require('base16-colorscheme').colors[c] or c end

function M.highlight()
  -- Separators sit on the statusline's own background, which is NONE when the theme is transparent
  local line_bg = vim.api.nvim_get_hl(0, { name = 'StatusLine', link = false }).bg
  for name, c in pairs(M.colors) do
    local fg, bg = resolve(c[1]), resolve(c[2])
    vim.api.nvim_set_hl(0, 'Stl' .. name, { fg = fg, bg = bg, bold = name ~= 'Info' })
    vim.api.nvim_set_hl(0, 'Stl' .. name .. 'Sep', { fg = bg, bg = line_bg })
  end
end

local function segment(name, text, open, close)
  if text == '' then return '' end
  return ('%%#Stl%sSep#%s%%#Stl%s# %s %%#Stl%sSep#%s'):format(name, open, name, text, name, close)
end

local function join(...)
  return table.concat(vim.tbl_filter(function(s) return s ~= '' end, { ... }), ' ')
end

local function fileinfo()
  local indent = (vim.bo.expandtab and '␣' or '⇥') .. vim.fn.shiftwidth()
  return join(indent, MiniStatusline.section_fileinfo { trunc_width = 120 })
end

function M.active()
  local sl = MiniStatusline
  local mode, mode_hl = sl.section_mode { trunc_width = 120 }
  local name = mode_hl:gsub('^MiniStatuslineMode', '')
  local devinfo = join(
    sl.section_git { trunc_width = 40 },
    sl.section_diff { trunc_width = 75 },
    sl.section_diagnostics { trunc_width = 75 },
    sl.section_lsp { trunc_width = 75 }
  )
  local position = join(sl.section_searchcount { trunc_width = 75 }, sl.section_location { trunc_width = 75 })

  return table.concat {
    segment(name, mode, glyphs.cap_l, glyphs.arrow_r),
    segment('Info', devinfo, glyphs.notch_l, glyphs.arrow_r),
    '%#StatusLine# %<',
    sl.section_filename { trunc_width = 140 },
    '%=',
    segment('Info', fileinfo(), glyphs.arrow_l, glyphs.notch_r),
    segment(name, position, glyphs.arrow_l, glyphs.cap_r),
  }
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
