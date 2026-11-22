-- Bible pickers (snacks.picker).
--   books()   pick a book
--   go()      pick a book; once what's typed names a single book, a space switches to its verses
--             in the same prompt: "exo 3:14" (straight to the verse), "exo 3" (the chapter),
--             "exo i am who" (verse text), "exo 3 burning" (text within chapter 3)
--   search()  full-text search (ripgrep) in the reading language
-- In all of them <M-l> / <M-h> switch the language without leaving the picker.
local data = require 'config.bible.data'
local ref = require 'config.bible.ref'

local M = {}

local function bible() return require 'config.bible' end

--- `s` padded to `width` display cells (names are Cyrillic/Greek, so not bytes)
local function pad(s, width) return s .. (' '):rep(math.max(1, width - vim.api.nvim_strwidth(s))) end

local function title(what) return ('%s · %s'):format(what, data.lang_name(data.lang())) end

-- Items -------------------------------------------------------------------------------------

--- Every book as an item, matching its names in every language
local function book_items(only)
  local lang = data.lang()
  local items = {}
  for _, b in ipairs(data.meta().books) do
    if not only or only[b.id] then
      local names = data.names(b, lang)
      local all = {}
      for _, l in ipairs(data.meta().lang_order) do
        vim.list_extend(all, b.names[l] or {})
      end
      local file_lang = data.lang_with(b.id, lang)
      local file = data.file(b.id, file_lang)
      local folded = {}
      for _, n in ipairs(all) do
        folded[#folded + 1] = ref.fold(n)
      end
      table.insert(items, {
        -- snacks only ignores case for ASCII: match on lowercased names, without accents
        text = table.concat(folded, ' '),
        book = b.id,
        name = names[1],
        abbr = names[2],
        missing = file_lang ~= lang and file_lang or nil,
        other = (b.names.en or {})[1] ~= names[1] and (b.names.en or {})[1] or nil,
        file = file,
        pos = { 1, 0 },
        order = b.order,
      })
    end
  end
  return items
end

local function format_book(item)
  local ret = {
    { pad(item.abbr, 8), 'SnacksPickerLabel' },
    { item.name },
  }
  if item.other then ret[#ret + 1] = { '  ' .. item.other, 'SnacksPickerComment' } end
  if item.missing then ret[#ret + 1] = { '  (only in ' .. data.lang_name(item.missing) .. ')', 'DiagnosticWarn' } end
  return ret
end

--- Verse items of a book, from chapter `ch` (and verse `v`) on when given
local function verse_items(book, ch, v)
  local lang = data.lang_with(book, data.lang())
  local path = lang and data.file(book, lang)
  if not path then return {} end
  local items = {}
  local abbr = data.names(book, lang)[2]
  local sep = lang:match '^sr' and ', ' or ':'
  for _, x in ipairs(data.parse(path).list) do
    if (not ch or x.ch == ch) and (not v or x.v >= v) then
      local num = ('%d%s%d%s'):format(x.ch, sep, x.v, x.sub)
      local plain = data.plain(x.text)
      table.insert(items, {
        -- Lowercased for matching (snacks folds only ASCII case); shown as written
        text = vim.fn.tolower(plain),
        display = plain,
        label = num,
        file = path,
        pos = { x.line, 0 },
        verse = x,
        abbr = abbr,
        ref = { book = book, ch = x.ch, v = x.v, sub = x.sub ~= '' and x.sub or nil },
      })
    end
  end
  return items
end

local function format_verse(item)
  local ret = { { pad(item.label, 9), 'SnacksPickerLabel' } }
  -- Matched characters highlighted, as snacks does for its own items
  local offset = Snacks.picker.highlight.offset(ret)
  ret[#ret + 1] = { item.display or item.text }
  if item.positions then Snacks.picker.highlight.matches(ret, item.positions, offset) end
  return ret
end

--- Books whose name/abbreviation is exactly what's typed rank first, then ones that start with it
local function boost(picker, pattern)
  local exact = {}
  for _, c in ipairs(ref._get_index().exact[pattern] or {}) do
    exact[c.book] = true
  end
  local prefixed = ref.books_with_prefix(pattern)
  for _, item in ipairs(picker.finder.items or {}) do
    if item.book and not item.verse then item.score_add = exact[item.book] and 2000 or prefixed[item.book] and 1000 or nil end
  end
end

-- Keys --------------------------------------------------------------------------------------

local function cycle(step)
  return function(picker)
    data.set_lang(data.next_lang(data.lang(), step))
    picker.title = title(picker.opts.bible_title)
    picker:find { refresh = true }
    picker:update_titles()
  end
end

local function keys()
  return {
    input = {
      keys = {
        ['<M-l>'] = { 'bible_lang_next', mode = { 'i', 'n' }, desc = 'Next language' },
        ['<M-h>'] = { 'bible_lang_prev', mode = { 'i', 'n' }, desc = 'Previous language' },
        -- live is how the verse mode works; turning it off would break it
        ['<C-g>'] = false,
      },
    },
  }
end

local actions = { bible_lang_next = cycle(1), bible_lang_prev = cycle(-1) }

local function confirm(picker, item)
  picker:close()
  if not item then return end
  if item.ref then return bible().open(item.ref) end
  if item.book then return bible().open { book = item.book, ch = 1 } end
end

-- Pickers -----------------------------------------------------------------------------------

function M.books()
  if not data.meta() then return end
  Snacks.picker {
    filter = {
      transform = function(picker, filter)
        filter.pattern = ref.fold(filter.pattern)
        boost(picker, filter.pattern)
      end,
    },
    bible_title = 'Bible books',
    title = title 'Bible books',
    finder = function() return book_items() end,
    format = format_book,
    sort = { fields = { 'score:desc', 'order' } },
    actions = actions,
    win = keys(),
    confirm = confirm,
    preview = 'file',
    layout = { preset = 'select', preview = false },
  }
end

--- What's typed → mode: { key, pattern, book?, ch?, v? }.
--- key decides the items (the finder re-runs only when it changes); pattern filters them.
local function mode(text)
  local lang = data.lang()
  -- Longest run of words, ending at a space, that names a single book
  local book, rest
  local i = 0
  while true do
    local s = text:find(' ', i + 1, true)
    if not s then break end
    local prefix = text:sub(1, s - 1)
    if vim.trim(prefix) ~= '' then
      local exact = ref.book(prefix, lang)
      local ids, n = ref.books_with_prefix(prefix)
      local id = exact or (n == 1 and next(ids)) or nil
      if id and (not book or id == book) then
        book, rest = id, text:sub(s + 1)
      elseif book then
        break
      end
    end
    i = s
  end
  if not book then return { key = 'books|' .. lang, pattern = text } end
  rest = vim.trim(rest)
  local key = book .. '|' .. lang
  -- "3", "3:14", "3, 14", "3.14", then maybe text: "3 burning"
  local ch, v, after = rest:match '^(%d+)%s*[:%.,]%s*(%d+)%l?%s*(.*)$'
  if not ch then
    ch, after = rest:match '^(%d+)%s*[:%.,]?%s*(.*)$'
  end
  if ch then return { key = key .. '|' .. ch .. '|' .. (v or ''), pattern = after, book = book, ch = tonumber(ch), v = tonumber(v) } end
  return { key = key, pattern = rest, book = book }
end
M._mode = mode

function M.go(initial)
  if not data.meta() then return end
  local current ---@type table
  Snacks.picker {
    bible_title = 'Bible',
    title = title 'Bible',
    search = initial or '',
    live = true,
    -- Rewrites the typed text into the mode key (for the finder) and the fuzzy part (for the matcher)
    filter = {
      transform = function(picker, filter)
        -- The untrimmed input: a trailing space is what switches to a book's verses
        current = mode(picker.input.filter.search)
        filter.search = current.key
        -- Books are matched folded (no accents, "1 x"), verses lowercased
        filter.pattern = current.book and vim.fn.tolower(current.pattern) or ref.fold(current.pattern)
        if not current.book then boost(picker, filter.pattern) end
      end,
    },
    finder = function()
      local m = current or mode ''
      if m.book then return verse_items(m.book, m.ch, m.v) end
      return book_items()
    end,
    format = function(item)
      if item.verse then return format_verse(item) end
      return format_book(item)
    end,
    -- Books keep canon order between equal scores; verses keep text order
    sort = { fields = { 'score:desc', 'order', 'idx' } },
    matcher = { sort_empty = false },
    actions = vim.tbl_extend('force', actions, {
      -- In book mode, <Tab> completes the highlighted book and moves on to its verses
      bible_complete = function(picker)
        local item = picker:current()
        if item and item.book and not item.verse then
          picker.input:set('', item.abbr .. ' ')
          picker:find { refresh = true }
        else
          picker:action 'list_down'
        end
      end,
    }),
    win = vim.tbl_deep_extend('force', keys(), { input = { keys = { ['<Tab>'] = { 'bible_complete', mode = { 'i', 'n' } } } } }),
    confirm = confirm,
    preview = 'file',
    layout = { preset = 'default' },
  }
end

--- Full-text search of the reading language (ripgrep; smart case)
function M.search(initial)
  local root = data.root()
  if not root then return end
  local lang = data.lang()
  Snacks.picker.grep {
    title = title 'Bible search',
    dirs = { root .. '/' .. lang },
    search = initial,
    glob = { '*.md' },
    -- Only verse lines (not headings); runs in a fast context, so plain string work only
    transform = function(item)
      local body = item.text:match '^.-:%d+:%d+:(.*)$'
      if not (body and body:match '^%d+%l?%-?%d*%. ') then return false end
    end,
    format = function(item)
      if item.resolve and not item.line then item.resolve() end
      if not item.bible_label then
        local book = data.locate(item.file)
        local v = book and data.verse_at_line(item.file, item.pos[1])
        item.bible_label = v and ref.format({ book = book, ch = v.ch, v = v.v, sub = v.sub ~= '' and v.sub or nil }, lang) or '?'
      end
      local ret = { { pad(item.bible_label, 14), 'SnacksPickerLabel' } }
      local offset = Snacks.picker.highlight.offset(ret)
      local text = (item.line or ''):gsub('^%d+%l?%-?%d*%. ', ''):gsub(data.BLOCK_ID, '')
      local cut = #(item.line or '') - #text
      ret[#ret + 1] = { text }
      local positions
      if item.positions then
        positions = {}
        for _, p in ipairs(item.positions) do
          if p > cut then table.insert(positions, p - cut) end
        end
      end
      if positions then Snacks.picker.highlight.matches(ret, positions, offset) end
      return ret
    end,
    actions = {
      bible_lang_next = function(picker)
        local s = picker.input.filter.search
        picker:close()
        data.set_lang(data.next_lang(lang, 1))
        M.search(s)
      end,
      bible_lang_prev = function(picker)
        local s = picker.input.filter.search
        picker:close()
        data.set_lang(data.next_lang(lang, -1))
        M.search(s)
      end,
    },
    win = {
      input = {
        keys = {
          ['<M-l>'] = { 'bible_lang_next', mode = { 'i', 'n' }, desc = 'Next language' },
          ['<M-h>'] = { 'bible_lang_prev', mode = { 'i', 'n' }, desc = 'Previous language' },
        },
      },
    },
  }
end

return M
