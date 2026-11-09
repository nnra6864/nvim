-- Obsidian-style lists and quotes in markdown, text and git commits:
--   <CR>    continues the line's item: - / * / + / - [ ] (a checked box continues unchecked) /
--           1. -> 2. (later items renumber) / > quotes and callouts, lists inside quotes too.
--           Mid-line, the rest of the line moves into the new item.
--           On an empty item it outdents, then removes the marker; on an empty > line it leaves the quote
--   <S-CR>  new line inside the same item: no marker, aligned with the item's text, quote kept
--   o       like <CR> at the end of the line
-- <CR> is wired through blink.cmp (plugins/blink.lua), so an open completion menu is accepted first.
local M = {}

M.filetypes = { markdown = true, text = true, gitcommit = true }

--- Splits a line into its quote prefix ("> ", "> > ", may include the indent after it), indent,
--- list marker and text. nil when it's neither quoted nor a list item
local function parse(line)
  local quote, rest = line:match '^(%s*>[> ]*)(.*)$'
  quote, rest = quote or '', rest or line
  local indent, marker, text = rest:match '^(%s*)([-*+] %[.%] ?)(.*)$'
  local num
  if not indent then
    indent, marker, text = rest:match '^(%s*)([-*+] )(.*)$'
  end
  if not indent then
    indent, num, marker, text = rest:match '^(%s*)(%d+)([.)] )(.*)$'
    if num then marker = num .. marker end
  end
  if not indent then
    if quote == '' then return nil end
    indent, marker, text = '', '', rest
  end
  return { quote = quote, indent = indent, marker = marker, text = text, num = tonumber(num) }
end

local function next_marker(p)
  if p.num then return (p.num + 1) .. p.marker:sub(#tostring(p.num) + 1) end
  return (p.marker:gsub('%[.%]', '[ ]'))
end

--- After the item numbered p.num at `row`, renumbers its following siblings (nested lines are skipped)
local function renumber(row, p)
  local n = p.num
  local depth = #p.quote + #p.indent
  for r = row + 1, vim.api.nvim_buf_line_count(0) do
    local line = vim.fn.getline(r)
    local q = parse(line)
    local q_depth = q and #q.quote + #q.indent or #line:match '^%s*'
    if q and q.num and q_depth == depth then
      n = n + 1
      local fixed = q.quote .. q.indent .. n .. q.marker:sub(#tostring(q.num) + 1) .. q.text
      if fixed ~= line then vim.fn.setline(r, fixed) end
    elseif line:match '^%s*$' or q_depth <= depth then
      break
    end
  end
end

local function set_line_and_cursor(row, lines, col)
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, lines)
  vim.api.nvim_win_set_cursor(0, { row + #lines - 1, col })
end

--- True when <CR> on the current line is ours to handle (blink.cmp asks before falling back)
function M.handles()
  if not M.filetypes[vim.bo.filetype] then return false end
  local p = parse(vim.api.nvim_get_current_line())
  -- Only past the marker; with the cursor inside the prefix, <CR> stays a plain newline
  return p ~= nil and vim.fn.col '.' - 1 >= #p.quote + #p.indent + #p.marker
end

--- <CR>, or <S-CR> when `same_item`. Call only when M.handles() (or as <S-CR>, which falls back itself)
function M.newline(same_item)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local p = parse(line)
  if not p then return vim.api.nvim_feedkeys(vim.keycode '<CR>', 'n', false) end
  local before, after = line:sub(1, col), line:sub(col + 1)

  if same_item then
    local prefix = p.quote .. p.indent .. string.rep(' ', vim.fn.strdisplaywidth(p.marker))
    return set_line_and_cursor(row, { before, prefix .. after }, #prefix)
  end

  if p.text:match '^%s*$' then
    if p.marker ~= '' and p.indent ~= '' then
      -- Empty nested item: one level out
      local indent = p.indent:sub(-1) == '\t' and p.indent:sub(1, -2)
        or p.indent:sub(1, math.max(0, #p.indent - vim.fn.shiftwidth()))
      local new = p.quote .. indent .. p.marker
      return set_line_and_cursor(row, { new }, #new)
    end
    -- Empty item: drop the marker; empty quote line: leave the quote
    local new = p.marker ~= '' and p.quote or ''
    return set_line_and_cursor(row, { new }, #new)
  end

  local prefix = p.quote .. p.indent .. (p.marker ~= '' and next_marker(p) or '')
  set_line_and_cursor(row, { before, prefix .. after }, #prefix)
  if p.num then renumber(row + 1, { quote = p.quote, indent = p.indent, num = p.num + 1 }) end
end

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('lists', { clear = true }),
  pattern = vim.tbl_keys(M.filetypes),
  callback = function(ev)
    vim.keymap.set('i', '<S-CR>', function() M.newline(true) end, { buffer = ev.buf, desc = 'New line in this item' })
    vim.keymap.set('n', 'o', function()
      if not parse(vim.api.nvim_get_current_line()) then return 'o' end
      return 'A<Cmd>lua require("config.lists").newline()<CR>'
    end, { buffer = ev.buf, expr = true, desc = 'Next list item / quote line' })
  end,
})

return M
