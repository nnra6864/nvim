-- References: "Jn 3:16", "Јн 3, 16", "Ин. 3:16-18", "1 Кор 13:4-7; 14:1", "Ps 50", "Α΄ Κορ 13:4",
-- "Jn 1:1 (el)". Book names and abbreviations of every language are accepted; numbering is the
-- same in all of them.
-- A reference is { book, ch, v?, v2?, ch2?, lang? } (v2/ch2: end of a range; lang: pinned translation).
-- Parsed ones also carry col/end_col, and cont when they continue the one before ("; 4:1", ", 8").
local data = require 'config.bible.data'

local M = {}

-- Normalising names ------------------------------------------------------------------------

local fold_map = {
  -- Greek accents and final sigma (monotonic; the aliases are monotonic too)
  ['ά'] = 'α',
  ['έ'] = 'ε',
  ['ή'] = 'η',
  ['ί'] = 'ι',
  ['ό'] = 'ο',
  ['ύ'] = 'υ',
  ['ώ'] = 'ω',
  ['ϊ'] = 'ι',
  ['ΐ'] = 'ι',
  ['ϋ'] = 'υ',
  ['ΰ'] = 'υ',
  ['ς'] = 'σ',
  -- Serbian Latin, so names match typed without diacritics
  ['š'] = 's',
  ['č'] = 'c',
  ['ć'] = 'c',
  ['ž'] = 'z',
  ['đ'] = 'dj',
  -- Russian ё
  ['ё'] = 'е',
  -- Greek numeral sign and apostrophes
  ['΄'] = "'",
  ['ʹ'] = "'",
  ['’'] = "'",
  ['ʼ'] = "'",
}
local numerals = { ['α'] = '1', ['β'] = '2', ['γ'] = '3', ['δ'] = '4', i = '1', ii = '2', iii = '3', iv = '4' }

--- Lowercase, without accents, numbered books as "1 x"
function M.fold(s)
  s = vim.fn.tolower(s):gsub('[\xC0-\xF7][\x80-\xBF]*', fold_map)
  s = s:gsub('[%.,]', ' '):gsub('%s+', ' ')
  s = vim.trim(s)
  -- "1кор" → "1 кор"
  s = s:gsub('^(%d)([^%d%s])', '%1 %2')
  -- Leading numeral: "α' κορ", "α κορ", "ii kings"; trailing: "κορ α'"
  local first, rest = s:match "^(%S+)'? (.+)$"
  if first then
    first = first:gsub("'$", '')
    if numerals[first] then s = numerals[first] .. ' ' .. rest end
  end
  local body, last = s:match '^(.+) (%S+)$'
  if body then
    local l = last:gsub("'$", '')
    if numerals[l] and l:match '^[αβγδ]$' then s = numerals[l] .. ' ' .. body end
  end
  return (s:gsub("'", ''))
end

-- Alias index ------------------------------------------------------------------------------

local function index()
  if M._index then return M._index end
  local meta = data.meta()
  if not meta then return { exact = {}, list = {} } end
  local exact, list = {}, {}
  for _, b in ipairs(meta.books) do
    for _, lang in ipairs(meta.lang_order) do
      for _, name in ipairs(b.names[lang] or {}) do
        local key = M.fold(name)
        exact[key] = exact[key] or {}
        table.insert(exact[key], { book = b.id, lang = lang })
        table.insert(list, { key = key, book = b.id, lang = lang })
      end
    end
  end
  M._index = { exact = exact, list = list }
  return M._index
end
M._index = nil
M._get_index = index

local function prefer(cands, lang)
  lang = lang or data.lang()
  for _, c in ipairs(cands) do
    if c.lang == lang then return c.book end
  end
  -- Same language in another script (sr-Latn reading, Cyrillic name)
  local family = lang:match '^[^-]+'
  for _, c in ipairs(cands) do
    if c.lang:match '^[^-]+' == family then return c.book end
  end
  return cands[1].book
end

--- Book id for an exact name or abbreviation (any language), or nil.
--- Where languages disagree ("1 Цар" is 1 Samuel in Russian, 1 Kings in Serbian), `lang` decides.
function M.book(name, lang)
  local cands = index().exact[M.fold(name)]
  return cands and prefer(cands, lang) or nil
end

--- Books whose name or abbreviation (any language) starts with `prefix`: { id = true }, count.
--- An exact match on its own counts as the only one, so "jn" is John, though "jn…" isn't.
function M.books_with_prefix(prefix)
  local key = M.fold(prefix)
  if key == '' then return {}, 0 end
  local exact = index().exact[key]
  if exact then
    local ids, n = {}, 0
    for _, c in ipairs(exact) do
      if not ids[c.book] then
        ids[c.book], n = true, n + 1
      end
    end
    if n == 1 then return ids, 1 end
  end
  local ids, n = {}, 0
  for _, e in ipairs(index().list) do
    if e.key:sub(1, #key) == key and not ids[e.book] then
      ids[e.book], n = true, n + 1
    end
  end
  return ids, n
end

-- Formatting -------------------------------------------------------------------------------

--- "Jn 3:16-18" in `lang` (Serbian writes "Јн 3, 16-18")
function M.format(r, lang)
  lang = lang or data.lang()
  local names = data.names(r.book, lang)
  local sep = lang:match '^sr' and ', ' or ':'
  local s = names[2] .. ' ' .. r.ch
  if not r.v and r.ch2 and r.ch2 ~= r.ch then s = s .. '-' .. r.ch2 end
  if r.v then
    s = s .. sep .. r.v .. (r.sub or '')
    if r.ch2 and r.ch2 ~= r.ch then
      s = s .. '-' .. r.ch2 .. sep .. r.v2
    elseif r.v2 and r.v2 ~= r.v then
      s = s .. '-' .. r.v2
    end
  end
  return s
end

--- A list of references written compactly: "Јн 1, 1-2; 3, 5; Јев 11, 3", "Rev 12:7, 17"
--- (the book once while it repeats, the chapter once while it does)
function M.format_list(refs, lang)
  lang = lang or data.lang()
  local out, prev = '', nil
  for _, r in ipairs(refs) do
    local s = M.format(r, lang)
    if prev and prev.book == r.book and r.v and prev.v then
      s = s:sub(#data.names(r.book, lang)[2] + 2)
      if prev.ch == r.ch and not prev.ch2 and not r.ch2 then
        out = out .. ', ' .. s:gsub('^%d+[:,]%s*', '')
      else
        out = out .. '; ' .. s
      end
    else
      out = out .. (prev and '; ' or '') .. s
    end
    prev = r
  end
  return out
end

--- "JHN.3.16-18", "GEN.8.21-9.2", "ISA.15", "PSA.1-3" (data/xrefs.json) → reference
function M.from_id(id)
  local book, rest = id:match '^(%w+)%.(.+)$'
  if not book then return end
  local ch, v, tail = rest:match '^(%d+)%.(%d+)(.*)$'
  if ch then
    local r = { book = book, ch = tonumber(ch), v = tonumber(v) }
    local c2, v2 = tail:match '^%-(%d+)%.(%d+)$'
    if c2 then
      r.ch2, r.v2 = tonumber(c2), tonumber(v2)
    else
      r.v2 = tonumber(tail:match '^%-(%d+)$')
    end
    return r
  end
  local c1, c2 = rest:match '^(%d+)%-?(%d*)$'
  if c1 then return { book = book, ch = tonumber(c1), ch2 = tonumber(c2) } end
end

--- Canonical id: "JHN.3.16"
function M.id(r) return ('%s.%d.%s'):format(r.book, r.ch, (r.v or '') .. (r.sub or '')) end

--- Does reference `r` include verse (ch, v)?
function M.contains(r, ch, v)
  local c1, v1 = r.ch, r.v or 1
  local c2, v2 = r.ch2 or r.ch, r.v2 or r.v or math.huge
  if not r.v then v2 = math.huge end
  local before = ch < c1 or (ch == c1 and v < v1)
  local after = ch > c2 or (ch == c2 and v > v2)
  return not before and not after
end

-- Parsing ----------------------------------------------------------------------------------

--- A range dash at byte `pos` ("-", "–", "—", spaces around): byte after it, or nil
local function dash(line, pos)
  local _, e = line:find('^%s*%-%s*', pos)
  if not e then
    _, e = line:find('^%s*–%s*', pos)
  end
  if not e then
    _, e = line:find('^%s*—%s*', pos)
  end
  return e and e + 1
end

--- After a dash at `pos`: "18" → v2, or "9:2" → ch2, v2
local function range(line, pos, verse_ok)
  local d = dash(line, pos)
  if not d then return end
  local s, e, a, b = line:find('^(%d+)[:%.](%d+)', d)
  if s and verse_ok then return e + 1, tonumber(b), tonumber(a) end
  s, e, a = line:find('^(%d+)', d)
  if s then return e + 1, tonumber(a) end
end

local function is_upper(c) return c ~= '' and vim.fn.tolower(c) ~= c end

--- The book name just before byte `pos` (1-based start of the chapter number) in `line`:
--- the longest run of up to 4 words that is a known name. Returns book, start col.
local function book_before(line, pos, lang)
  local before = line:sub(math.max(1, pos - 60), pos - 1)
  local offset = math.max(1, pos - 60) - 1
  -- Name glued to the number ("Jn3:16") or separated by spaces / a dot ("Ин. 3:16")
  local stem = before:match '^(.-)[%s%.]*$'
  if stem == '' then return end
  -- Word starts, from the end
  local starts = {}
  local i = #stem
  while i >= 1 and #starts < 4 do
    -- back over the word
    while i >= 1 and not stem:sub(i, i):match '[%s%(%[;,/]' do
      i = i - 1
    end
    table.insert(starts, i + 1)
    while i >= 1 and stem:sub(i, i):match '%s' do
      i = i - 1
    end
    if i >= 1 and stem:sub(i, i):match '[%(%[;,/]' then break end
  end
  for k = #starts, 1, -1 do
    local s = starts[k]
    local name = stem:sub(s)
    local id = M.book(name, lang)
    if id then return id, offset + s, name end
  end
end

--- Links to a verse or chapter of a book file: [[56 John#^3-16]], [[56 John#^3-16|Jn 3:16-18]]
--- (the alias can widen it to a range), [[56 John#3|Jn 3]]. Marked `link`.
local function wikilinks(line)
  local out = {}
  if not line:find('[[', 1, true) then return out end
  for s, inner, e in line:gmatch '()%[%[([^%[%]]-)%]%]()' do
    local target, anchor, alias = inner:match '^([^#|]+)#([^|]*)|?(.*)$'
    local book = target and data.link_book(vim.trim(target))
    if book then
      local r
      local c, v, sub = anchor:match '^%^(%d+)%-(%d+)(%l?)$'
      if c then
        r = { book = book, ch = tonumber(c), v = tonumber(v), sub = sub ~= '' and sub or nil }
      elseif anchor:match '^%d+$' then
        r = { book = book, ch = tonumber(anchor) }
      end
      if r then
        local a = alias ~= '' and M.parse(alias, { loose = true })[1]
        if a and a.book == r.book and a.ch == r.ch and a.v == r.v then
          r.v2, r.ch2 = a.v2, a.ch2
        end
        r.col, r.end_col, r.link = s - 1, e - 1, true
        table.insert(out, r)
      end
    end
  end
  return out
end

--- Link to `r` in the book file of `lang`: [[56 John#^3-16|Jn 3:16-18]] (to its first verse, the
--- alias saying the rest), [[56 John#3|Jn 3]]. Obsidian jumps to the verse; the plugin reads it as `r`.
function M.wikilink(r, lang)
  lang = data.lang_with(r.book, lang or data.lang())
  local target = lang and data.link_target(r.book, lang)
  if not target then return end
  local anchor = r.v and ('^' .. data.block_id(r.ch, r.v, r.sub)) or tostring(r.ch)
  return ('[[%s#%s|%s]]'):format(target, anchor, M.format(r, lang))
end

--- All references in a line: { {book, ch, v, v2, ch2, lang, col, end_col}, ... } (0-based, end exclusive).
--- Links to Bible files count too ([[56 John#^3-16|…]]). `opts.lang` resolves names that differ between languages; `opts.loose` accepts chapter-only
--- references with lowercase names ("ps 50"), which in prose would also match "am 3".
function M.parse(line, opts)
  opts = opts or {}
  local meta = data.meta()
  if not meta or not line:find '%d' then return {} end
  local out = {}
  local pos = 1
  while true do
    local s, e = line:find('%d+', pos)
    if not s then break end
    local book, start, name = book_before(line, s, opts.lang)
    -- Not the middle of a word or number ("x12", "3 12")
    if book and start > 1 and line:sub(start - 1, start - 1):match '[%w]' then book = nil end
    if not book then
      pos = e + 1
    else
      local ch = tonumber(line:sub(s, e))
      local r = { book = book, ch = ch, col = start - 1 }
      local rest = e + 1
      -- Verse: "3:16", "3.16", "3, 16" (Serbian)
      local vs, ve, v, sub = line:find('^%s*[:%.,]%s*(%d+)(%l?)', rest)
      if vs then
        r.v, r.sub = tonumber(v), sub ~= '' and sub or nil
        rest = ve + 1
        -- Range: "-18", "–18", "-4:2"
        local after, v2, ch2 = range(line, rest, true)
        if after then
          r.v2, r.ch2, rest = v2, ch2, after
        end
      else
        -- Chapter only: needs a capitalised name, so prose doesn't light up
        if not opts.loose and not is_upper(vim.fn.strcharpart(name, 0, 1)) and not name:match '^%d' then book = nil end
        local after, ch2 = range(line, rest)
        if book and after then
          r.ch2, rest = ch2, after
        end
      end
      if book then
        local b = data.book(book)
        -- Chapters beyond the book's end aren't references ("Ps 2024")
        if b and ch >= 1 and ch <= #b.verses then
          -- Pinned translation: "(el)", "[sr-Latn]"
          local ls, le, code = line:find('^%s*[%(%[]([%a%-]+)[%)%]]', rest)
          if ls and meta.langs[code] then
            r.lang, rest = code, le + 1
          end
          r.end_col = rest - 1
          table.insert(out, r)
          -- Continuations: "; 4:1" (same book), ", 20" (same chapter)
          while true do
            local cs, ce, c2, v2 = line:find('^%s*;%s*(%d+)[:%.,]%s*(%d+)', rest)
            if cs then
              local n = { book = book, ch = tonumber(c2), v = tonumber(v2), lang = r.lang, cont = true }
              rest = ce + 1
              n.col = line:find('%d', cs) - 1
              local after, v2 = range(line, rest)
              if after then
                n.v2, rest = v2, after
              end
              n.end_col = rest - 1
              table.insert(out, n)
            else
              local ls2, le2, v3 = line:find('^,%s*(%d+)', rest)
              local prev = out[#out]
              if ls2 and prev.v and not line:find('^,%s*%d+%s*[:%.]', rest) then
                local n = { book = book, ch = prev.ch2 or prev.ch, v = tonumber(v3), lang = r.lang, cont = true }
                n.col = line:find('%d', ls2) - 1
                rest = le2 + 1
                local after, v2 = range(line, rest)
                if after then
                  n.v2, rest = v2, after
                end
                n.end_col = rest - 1
                table.insert(out, n)
              else
                break
              end
            end
          end
        end
      end
      pos = math.max(rest, e + 1)
    end
  end
  -- Links to Bible files: one reference each, instead of what's inside them
  local links = wikilinks(line)
  if #links > 0 then
    out = vim.tbl_filter(function(r)
      for _, l in ipairs(links) do
        if r.col < l.end_col and r.end_col > l.col then return false end
      end
      return true
    end, out)
    vim.list_extend(out, links)
    table.sort(out, function(a, b) return a.col < b.col end)
  end
  return out
end

--- The reference under (0-based) column `col` of `line`
function M.at(line, col, opts)
  for _, r in ipairs(M.parse(line, opts)) do
    if col >= r.col and col < r.end_col then return r end
  end
end

--- A reference typed on its own (":Bible jn 3:16", the picker): lowercase names allowed
function M.parse_one(text, lang) return M.parse(text, { loose = true, lang = lang })[1] end

return M
