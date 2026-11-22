-- blink.cmp source for Markdown: Bible book names (inserted as the reading language's
-- abbreviation, "Jn "), and after "Jn 3:" / "Јн 3, " the chapter's verse numbers, each with its text.
local source = {}

function source.new() return setmetatable({}, { __index = source }) end

function source:enabled() return vim.bo.filetype == 'markdown' and require('config.bible.data').root() ~= nil end

function source:get_trigger_characters() return { ':', ',' } end

local Kind = vim.lsp.protocol.CompletionItemKind

local function empty(callback)
  callback { items = {}, is_incomplete_forward = false, is_incomplete_backward = false }
  return function() end
end

--- Book named by the last 1-3 words of `head`
local function book_at_end(head)
  local ref = require 'config.bible.ref'
  local words = vim.split(vim.trim(head), '%s+')
  for n = math.min(3, #words), 1, -1 do
    local name = table.concat(vim.list_slice(words, #words - n + 1, #words), ' ')
    name = name:gsub('^[%(%[;,/]+', '')
    local id = name ~= '' and ref.book(name)
    if id then return id end
  end
end

function source:get_completions(ctx, callback)
  local data = require 'config.bible.data'
  local ref = require 'config.bible.ref'
  if not data.meta() then return empty(callback) end
  local col = ctx.cursor[2]
  local before = ctx.line:sub(1, col)
  local row = ctx.cursor[1] - 1
  local lang = data.lang()

  -- Verse numbers: "<book> <ch>:" / "<book> <ch>, " / "<book> <ch>:1"
  local head, ch, partial = before:match '^(.-)%s*(%d+)%s*[:,]%s*(%d*)$'
  local book = head and book_at_end(head)
  if book then
    local verses = require('config.bible').verses({ book = book, ch = tonumber(ch) }, lang)
    if #verses > 0 then
      local items = {}
      for _, v in ipairs(verses) do
        local num = v.v .. v.sub
        local text = data.plain(v.text)
        table.insert(items, {
          label = num,
          labelDetails = { description = vim.fn.strcharpart(text, 0, 50) .. (vim.fn.strchars(text) > 50 and '…' or '') },
          kind = Kind.Reference,
          sortText = ('%04d%s'):format(v.v, v.sub),
          filterText = num,
          textEdit = { newText = num, range = { start = { line = row, character = col - #partial }, ['end'] = { line = row, character = col } } },
          documentation = { kind = 'markdown', value = ('**%s**\n\n%s'):format(ref.format({ book = book, ch = v.ch, v = v.v, sub = v.sub ~= '' and v.sub or nil }, lang), v.text) },
        })
      end
      callback { items = items, is_incomplete_forward = false, is_incomplete_backward = false }
      return function() end
    end
  end

  -- Book names: the word being typed, with a leading number ("1 ko", "1ko")
  local start, word = before:match '()(%d?%s?[^%s%d%(%[;,/:%.]+)$'
  if not word or #word < 2 then return empty(callback) end
  local items = {}
  for _, b in ipairs(data.meta().books) do
    local names = data.names(b, lang)
    local alt = {}
    for _, l in ipairs(data.meta().lang_order) do
      if l ~= lang then vim.list_extend(alt, b.names[l] or {}) end
    end
    table.insert(items, {
      label = names[2],
      labelDetails = { description = names[1] },
      kind = Kind.Module,
      -- Matches its names in the reading language; other languages' names too, after them
      filterText = table.concat(names, ' ') .. ' ' .. table.concat(alt, ' '),
      sortText = ('%03d'):format(b.order),
      textEdit = { newText = names[2] .. ' ', range = { start = { line = row, character = start - 1 }, ['end'] = { line = row, character = col } } },
      documentation = { kind = 'markdown', value = ('**%s**\n\n%s'):format(names[1], table.concat(names, ', ')) },
    })
  end
  callback { items = items, is_incomplete_forward = false, is_incomplete_backward = false }
  return function() end
end

return source
