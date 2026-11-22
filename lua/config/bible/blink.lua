-- blink.cmp source for Markdown: Bible book names (inserted as the reading language's
-- abbreviation, "Jn "), and after "Jn 3:" / "Јн 3, " the chapter's verse numbers, each with its text.
-- Inside [[ ]] they make links: "[[Jn 3:" offers each verse as [[56 John#^3-16|Jn 3:16]], and a
-- typed reference ("[[Jn 3:16-18", "[[Jn 3") becomes a link to it.
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

  -- In a link being typed ("[[Jn 3:16"): items replace it from "[[" (and a "]]" after the cursor)
  local link_start, inner = before:match '()%[%[([^%[%]|#]*)$'
  local link_range
  if link_start then
    local close = ctx.line:sub(col + 1, col + 2) == ']]' and 2 or 0
    link_range = { start = { line = row, character = link_start - 1 }, ['end'] = { line = row, character = col + close } }
  end
  local function link_item(r, label, sort, extra)
    local link = ref.wikilink(r, lang)
    if not link then return end
    return vim.tbl_extend('force', {
      label = label,
      kind = Kind.Reference,
      sortText = sort,
      filterText = inner,
      score_offset = 20,
      textEdit = { newText = link, range = link_range },
    }, extra or {})
  end

  local items = {}
  -- A whole reference typed: its link
  local typed = inner and inner:match '%d' and ref.parse_one(inner, lang)
  -- (a single verse is among the verse numbers below)
  local single = typed and typed.v and not typed.v2 and not typed.ch2
  if typed and typed.col == 0 and typed.end_col == #inner and not typed.cont and not single then
    local verses = require('config.bible').verses(typed, lang)
    local text = vim.tbl_map(function(v) return data.plain(v.text) end, verses)
    local it = link_item(typed, ref.format(typed, lang), '0', {
      labelDetails = { description = 'link' },
      documentation = { kind = 'markdown', value = ('**%s**\n\n%s'):format(ref.format(typed, lang), table.concat(text, ' ')) },
    })
    if it then table.insert(items, it) end
  end

  -- Verse numbers: "<book> <ch>:" / "<book> <ch>, " / "<book> <ch>:1"
  local head, ch, partial = before:match '^(.-)%s*(%d+)%s*[:,]%s*(%d*)$'
  local book = head and book_at_end(head)
  if book then
    local verses = require('config.bible').verses({ book = book, ch = tonumber(ch) }, lang)
    if #verses > 0 then
      for _, v in ipairs(verses) do
        local num = v.v .. v.sub
        local text = data.plain(v.text)
        local r = { book = book, ch = v.ch, v = v.v, sub = v.sub ~= '' and v.sub or nil }
        local it = link_start
          and link_item(r, num, ('%04d%s'):format(v.v, v.sub), {
            filterText = num,
            labelDetails = { description = vim.fn.strcharpart(text, 0, 50) .. (vim.fn.strchars(text) > 50 and '…' or '') },
            documentation = { kind = 'markdown', value = ('**%s**\n\n%s'):format(ref.format(r, lang), v.text) },
          })
        if it then
          -- blink matches filterText against the word being typed: the verse number
          it.score_offset = nil
          table.insert(items, it)
        else
          table.insert(items, {
            label = num,
            labelDetails = { description = vim.fn.strcharpart(text, 0, 50) .. (vim.fn.strchars(text) > 50 and '…' or '') },
            kind = Kind.Reference,
            sortText = ('%04d%s'):format(v.v, v.sub),
            filterText = num,
            textEdit = { newText = num, range = { start = { line = row, character = col - #partial }, ['end'] = { line = row, character = col } } },
            documentation = { kind = 'markdown', value = ('**%s**\n\n%s'):format(ref.format(r, lang), v.text) },
          })
        end
      end
      -- In a link, typing on ("16-18") changes the link offered
      callback { items = items, is_incomplete_forward = link_start ~= nil, is_incomplete_backward = link_start ~= nil }
      return function() end
    end
  end

  if #items > 0 then
    callback { items = items, is_incomplete_forward = true, is_incomplete_backward = true }
    return function() end
  end

  -- Book names: the word being typed, with a leading number ("1 ko", "1ko")
  local start, word = before:match '()(%d?%s?[^%s%d%(%[;,/:%.]+)$'
  if not word or #word < 2 then return empty(callback) end
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
