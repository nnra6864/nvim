-- The Bible in the vault (built by ~/Data/Projects/Scraper/bible): where it is, its books and
-- languages, the language you read in (remembered per machine), and the verses of a book file.
-- Every translation uses the same (Russian Synodal) numbering, so a verse is the same
-- book/chapter/verse in every language.
local M = {}

local state_file = vim.fn.stdpath 'state' .. '/bible.json'
local BIBLE_DIR = 'Resources/Religion/Bible'

local function exists(path) return path and vim.uv.fs_stat(path) ~= nil end

--- The Bible folder: vim.g.bible_root, else the one in the current (or last used) vault,
--- else the one in ~/Documents/Obsidian/nn
function M.root()
  if M._root then return M._root end
  local candidates = { vim.g.bible_root }
  local ok, notes = pcall(require, 'config.notes')
  local vault = ok and notes.current() or nil
  if vault then table.insert(candidates, vault .. '/' .. BIBLE_DIR) end
  table.insert(candidates, vim.fs.normalize '~/Documents/Obsidian/nn/' .. BIBLE_DIR)
  for _, c in pairs(candidates) do
    if exists(c .. '/books.json') then
      M._root = vim.fs.normalize(vim.uv.fs_realpath(c) or c)
      return M._root
    end
  end
end

local function read_json(path)
  local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), '\n')) end)
  return ok and data or nil
end

--- books.json: { langs = {code = name}, books = { {id, order, testament, names = {lang = {name, abbr, ...}}, verses, langs} } }
function M.meta()
  if M._meta then return M._meta end
  local root = M.root()
  local meta = root and read_json(root .. '/books.json')
  if not meta then
    vim.notify('Bible not found (looked for ' .. BIBLE_DIR .. '/books.json)', vim.log.levels.ERROR)
    return nil
  end
  meta.by_id = {}
  for _, b in ipairs(meta.books) do
    meta.by_id[b.id] = b
    b.has = {}
    for _, l in ipairs(b.langs) do
      b.has[l] = true
    end
  end
  -- Language order as built (sr-Cyrl, sr-Latn, ru, el, en): books.json keeps it in each book's names
  meta.lang_order = {}
  for lang in pairs(meta.books[1].names) do
    table.insert(meta.lang_order, lang)
  end
  local pref = { 'sr-Cyrl', 'sr-Latn', 'ru', 'el', 'en' }
  local rank = {}
  for i, l in ipairs(pref) do
    rank[l] = i
  end
  table.sort(meta.lang_order, function(a, b) return (rank[a] or 99) < (rank[b] or 99) end)
  M._meta = meta
  return meta
end

function M.book(id)
  local meta = M.meta()
  return meta and meta.by_id[id]
end

-- Language ---------------------------------------------------------------------------------

--- Remembered settings (language, follower language, cross-references shown): a table to change,
--- then M.save_state()
function M.state()
  if M._state then return M._state end
  M._state = read_json(state_file) or {}
  return M._state
end

function M.save_state() pcall(vim.fn.writefile, { vim.json.encode(M._state) }, state_file) end

--- The language Bible text opens in
function M.lang()
  local s = M.state()
  local meta = M.meta()
  if meta and s.lang and meta.langs[s.lang] then return s.lang end
  return 'en'
end

function M.set_lang(lang)
  M.state().lang = lang
  M.save_state()
  vim.api.nvim_exec_autocmds('User', { pattern = 'BibleLang', data = { lang = lang } })
end

--- The language after (or before, step -1) `lang` in the cycle
function M.next_lang(lang, step)
  local order = M.meta().lang_order
  local i = 1
  for k, l in ipairs(order) do
    if l == lang then i = k end
  end
  return order[(i - 1 + (step or 1)) % #order + 1]
end

function M.lang_name(lang) return (M.meta().langs or {})[lang] or lang end

--- A book's names in a language ({name, abbr, aliases...}); falls back to English
function M.names(book, lang)
  local b = type(book) == 'table' and book or M.book(book)
  return b.names[lang] or b.names.en
end

-- Files ------------------------------------------------------------------------------------

--- Path of a book's file in a language, or nil when that language lacks the book
function M.file(id, lang)
  local root, b = M.root(), M.book(id)
  if not (root and b and b.has[lang]) then return end
  M._files = M._files or {}
  local key = lang .. '/' .. id
  if M._files[key] == nil then
    M._files[key] = false
    local prefix = ('%02d '):format(b.order)
    for name, type in vim.fs.dir(root .. '/' .. lang) do
      if type == 'file' and name:sub(1, #prefix) == prefix then M._files[key] = root .. '/' .. lang .. '/' .. name end
    end
  end
  return M._files[key] or nil
end

--- The language to open a book in: `lang` when it has the book, else the first that does
function M.lang_with(id, lang)
  local b = M.book(id)
  if not b then return end
  if b.has[lang] then return lang end
  for _, l in ipairs(M.meta().lang_order) do
    if b.has[l] then return l end
  end
end

--- If `path` is a book file: book id, lang
function M.locate(path)
  local root = M.root()
  if not (root and path and path ~= '') then return end
  path = vim.fs.normalize(path)
  if path:sub(1, #root + 1) ~= root .. '/' then
    local real = vim.uv.fs_realpath(path)
    if not real or real:sub(1, #root + 1) ~= root .. '/' then return end
    path = real
  end
  local lang, name = path:sub(#root + 2):match '^([^/]+)/(%d+) .*%.md$'
  if not lang then return end
  local book = M.meta().books[tonumber(name)]
  if book then return book.id, lang end
end

--- Verses of a book file: { list = {verse...}, at = {['3:16'] = verse}, chapters = {[3] = line} }
--- verse = { ch, v, sub, to, line, text }. Read from the buffer when it's loaded.
function M.parse(path)
  local buf = vim.fn.bufnr(path)
  local lines ---@type string[]
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local cached = vim.b[buf].bible_parsed_tick == tick and M._by_buf and M._by_buf[buf]
    if cached then return cached end
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    M._by_buf = M._by_buf or {}
    M._by_buf[buf] = M._parse_lines(lines)
    vim.b[buf].bible_parsed_tick = tick
    return M._by_buf[buf]
  else
    M._parsed = M._parsed or {}
    local stat = vim.uv.fs_stat(path)
    local cached = M._parsed[path]
    if cached and stat and cached.mtime == stat.mtime.sec then return cached end
    lines = vim.fn.readfile(path)
    local res = M._parse_lines(lines)
    res.mtime = stat and stat.mtime.sec
    M._parsed[path] = res
    return res
  end
end

function M._parse_lines(lines)
  local res = { list = {}, at = {}, chapters = {} }
  local ch = 0
  for i, line in ipairs(lines) do
    local c = line:match '^## (%d+)%s*$'
    if c then
      ch = tonumber(c)
      res.chapters[ch] = i
    elseif ch > 0 then
      local v, sub, to, text = line:match '^(%d+)(%l?)%-?(%d*)%. (.*)$'
      if v then
        local verse = { ch = ch, v = tonumber(v), sub = sub, to = tonumber(to), line = i, text = text }
        table.insert(res.list, verse)
        res.at[ch .. ':' .. v .. sub] = res.at[ch .. ':' .. v .. sub] or verse
        -- A verse printed together with the next ones ("1-2.") answers for each of them
        for n = verse.v + 1, verse.to or verse.v do
          res.at[ch .. ':' .. n] = res.at[ch .. ':' .. n] or verse
        end
      end
    end
  end
  return res
end

--- The verse printed on line `lnum` of a book file
function M.verse_at_line(path, lnum)
  local p = M.parse(path)
  if not p.by_line then
    p.by_line = {}
    for _, v in ipairs(p.list) do
      p.by_line[v.line] = v
    end
  end
  return p.by_line[lnum]
end

--- Verse text without the italics marking translators' additions
function M.plain(text) return (text:gsub('%*', '')) end

--- Cross-references and footnotes of a language: { ['JHN.3.16'] = {xrefs = {...}, notes = {...}} }
function M.extras(lang)
  M._extras = M._extras or {}
  if M._extras[lang] == nil then
    local root = M.root()
    M._extras[lang] = root and read_json(root .. '/data/' .. lang .. '.json') or {}
  end
  return M._extras[lang]
end

--- data/xrefs.json: { sources = { key = name }, refs = { ["GEN.1.1"] = { sr = { "JHN.1.1-2", ... } } } },
--- every target in the Synodal numbering
function M.xrefs()
  if M._xrefs == nil then
    local root = M.root()
    M._xrefs = root and read_json(root .. '/data/xrefs.json') or { sources = {}, refs = {} }
  end
  return M._xrefs
end

-- Sets shown unless turned off (OpenBible's is off unless turned on)
local XREF_DEFAULT = { sr = true, en = true, openbible = false }
M.XREF_ORDER = { 'sr', 'en', 'openbible' }

function M.xref_source_on(key)
  local on = (M.state().xref_sources or {})[key]
  if on == nil then return XREF_DEFAULT[key] ~= false end
  return on
end

function M.set_xref_source(key, on)
  local st = M.state()
  st.xref_sources = st.xref_sources or {}
  st.xref_sources[key] = on
  M.save_state()
end

return M
