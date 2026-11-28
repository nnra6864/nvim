-- Indent scope (blue guide, ii/ai, [i ]i) in Markdown follows the list structure.
-- snacks' treesitter scope breaks here: Markdown nodes end at column 0 of the next line, so a
-- list item without children counts as two lines and becomes the scope, lighting nothing.
-- Plain indent scope can't tell where one top-level item ends and the next starts.
-- So in a list: the scope is the item the cursor line belongs to if it has nested items,
-- else the item it's nested in, else none. Outside lists: indent scope.
local M = {}

--- The list item that owns `row` (0-based) and has nested items, or false when in a list
--- with no such item, or nil when not in a list
---@return {from: integer, to: integer}|false|nil
local function list_scope(buf, row)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'markdown', { error = false })
  if not ok or not parser then return end
  parser:parse { row, row + 1 }
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
  local col = (line:find '%S' or 1) - 1
  local node = parser:named_node_for_range({ row, col, row, col + 1 }, { ignore_injections = true })
  local in_list = false
  while node do
    if node:type() == 'list_item' then
      in_list = true
      for child in node:iter_children() do
        if child:type() == 'list' then
          local from, _, to, ecol = node:range()
          if ecol == 0 then to = to - 1 end -- ends at column 0 of the next line
          to = vim.fn.prevnonblank(to + 1) -- items keep the blank lines after them
          return { from = from + 1, to = to }
        end
      end
    end
    node = node:parent()
  end
  if in_list then return false end
end

function M.setup()
  local get = Snacks.scope.get
  ---@diagnostic disable-next-line: duplicate-set-field
  Snacks.scope.get = function(cb, opts)
    local buf = opts and opts.buf ~= 0 and opts.buf or vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype ~= 'markdown' or (opts and opts.md_scope) then return get(cb, opts) end
    opts = vim.tbl_deep_extend('force', opts or {}, { md_scope = true, treesitter = { enabled = false } })
    local row = (opts.pos or vim.api.nvim_win_get_cursor(0))[1] - 1
    get(function(scope)
      local s = list_scope(buf, row)
      if s == false or (s and not scope) then return cb(nil) end
      if s then scope = scope:with { from = s.from, to = s.to, indent = vim.fn.indent(s.from) } end
      cb(scope)
    end, opts)
  end
end

return M
