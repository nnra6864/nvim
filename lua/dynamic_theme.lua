local M = {}
local uv = vim.uv or vim.loop
local watch_dir = vim.fn.expand("~/.config/nvim/lua")

local function apply_transparency()
  local groups = {
    "Normal",
    "NormalNC",
    "NormalFloat",
    "FloatBorder",
    "FloatTitle",
    "SignColumn",
    "LineNr",
    "CursorLine",
    "CursorLineNr",
    "CursorLineSign",
    "EndOfBuffer",
    "NonText",
    "StatusLine",
    "StatusLineNC",
    "WinSeparator",
    "VertSplit",
    "Pmenu",
    "PmenuSel",
    "PmenuSbar",
    "PmenuThumb",
    "TabLine",
    "TabLineFill",
    "TabLineSel",
    "TelescopeNormal",
    "TelescopeBorder",
    "NvimTreeNormal",
    "NvimTreeNormalNC",
    "Folded",
    "FoldColumn",
  }

  for _, group in ipairs(groups) do
    vim.cmd(string.format("highlight %s guibg=NONE ctermbg=NONE", group))
  end
end

function M.reload()
  package.loaded["theme"] = nil
  local ok, palette = pcall(require, "theme")
  if ok and type(palette) == "table" then
    require("base16-colorscheme").setup(palette)

    if palette.transparent == true then
      apply_transparency()
    end
  end
end

function M.setup()
  M.reload()

  local watcher = uv.new_fs_event()
  if watcher then
    watcher:start(watch_dir, {}, vim.schedule_wrap(function(err, filename)
      if not err and filename == "theme.lua" then
        M.reload()
      end
    end))
  end
end

return M
