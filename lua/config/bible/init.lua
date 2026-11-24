-- The Bible in the vault: opening references, the verse under the cursor, hover with every
-- translation, quoting, backlinks, and the cross-references/footnotes (hidden unless toggled).
-- Pickers live in config/bible/picker.lua, the follower split in config/bible/follow.lua,
-- completion in config/bible/blink.lua. Keymaps are in config/keymaps.lua.
local data = require 'config.bible.data'
local ref = require 'config.bible.ref'

local M = {}
M.data, M.ref = data, ref

local ns = vim.api.nvim_create_namespace 'bible'
local ns_extras = vim.api.nvim_create_namespace 'bible-extras'
local ns_ids = vim.api.nvim_create_namespace 'bible-block-ids'

-- Windows ----------------------------------------------------------------------------------

local function is_float(win) return vim.api.nvim_win_get_config(win).relative ~= '' end

--- A window to open Bible text in: the current one, unless it's a float or the follower split
function M.target_win()
  local follower = require('config.bible.follow').win()
  local cur = vim.api.nvim_get_current_win()
  if not is_float(cur) and cur ~= follower then return cur end
  local prev = vim.fn.win_getid(vim.fn.winnr '#')
  if prev ~= 0 and not is_float(prev) and prev ~= follower then return prev end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not is_float(w) and w ~= follower then return w end
  end
  return cur
end

-- Where the cursor is ----------------------------------------------------------------------

--- The verse at the cursor in a Bible buffer: { book, lang, ch, v?, sub?, line }, or nil.
--- Above a chapter's first verse (heading, title) it's the chapter with no verse.
function M.cursor_verse(win)
  win = win or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local book, lang = data.locate(vim.api.nvim_buf_get_name(buf))
  if not book then return end
  local row = vim.api.nvim_win_get_cursor(win)[1]
  local p = data.parse(vim.api.nvim_buf_get_name(buf))
  local best
  for _, v in ipairs(p.list) do
    if v.line > row then break end
    best = v
  end
  local ch
  for c, line in pairs(p.chapters) do
    if line <= row and (not ch or line > p.chapters[ch]) then ch = c end
  end
  if not ch then return { book = book, lang = lang, ch = 1, line = row } end
  if best and best.ch == ch then
    return { book = book, lang = lang, ch = ch, v = best.v, sub = best.sub ~= '' and best.sub or nil, line = best.line, verse = best }
  end
  return { book = book, lang = lang, ch = ch, line = row }
end

--- The reference written under the cursor, or nil. Not in Bible buffers, where the verse
--- at the cursor (M.cursor_verse) is what counts
function M.cursor_ref(win)
  win = win or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local line = vim.api.nvim_buf_get_lines(buf, cursor[1] - 1, cursor[1], false)[1] or ''
  local book = data.locate(vim.api.nvim_buf_get_name(buf))
  -- Verse numbers in Bible text ("16. For God...") aren't references, so only parse notes
  if not book then return ref.at(line, cursor[2]) end
end

-- Opening ----------------------------------------------------------------------------------

--- Line of reference `r` in the book file `path` (the verse, else the chapter heading)
local function line_of(path, r)
  local p = data.parse(path)
  if r.v then
    local v = p.at[r.ch .. ':' .. r.v .. (r.sub or '')] or p.at[r.ch .. ':' .. r.v]
    if v then return v.line end
    -- Past the chapter's last verse: its last verse
    local last
    for _, x in ipairs(p.list) do
      if x.ch == r.ch then last = x end
    end
    if last then return last.line end
  end
  return p.chapters[r.ch] or 1
end
M.line_of = line_of

--- Lines of the verses of `r` in `path`: first, last
local function lines_of(path, r)
  local first = line_of(path, r)
  if not r.v then return first, first end
  local last = first
  if r.v2 or r.ch2 then
    local p = data.parse(path)
    for _, x in ipairs(p.list) do
      if ref.contains(r, x.ch, x.v) then last = math.max(last, x.line) end
    end
  end
  return first, last
end

local function flash(buf, first, last) vim.hl.range(buf, ns, 'Search', { first - 1, 0 }, { last - 1, -1 }, { timeout = 600 }) end

--- Opens reference `r` (in r.lang, opts.lang, else the reading language).
--- opts: lang, win, split ('vsplit'|'split'|'tab'), flash (default true)
function M.open(r, opts)
  opts = opts or {}
  local want = r.lang or opts.lang or data.lang()
  local lang = data.lang_with(r.book, want)
  if not lang then return vim.notify('Unknown book ' .. tostring(r.book), vim.log.levels.WARN) end
  if lang ~= want then vim.notify(("%s isn't in %s; showing %s"):format(data.names(r.book, 'en')[1], data.lang_name(want), data.lang_name(lang))) end
  local path = data.file(r.book, lang)
  if not path then return end
  local cur = vim.api.nvim_get_current_win()
  if is_float(cur) then pcall(vim.api.nvim_win_close, cur, false) end
  local win = opts.win or M.target_win()
  vim.api.nvim_set_current_win(win)
  if opts.split == 'tab' then
    vim.cmd 'tab split'
  elseif opts.split then
    vim.cmd(opts.split)
  end
  -- Into the jumplist, so <C-o> comes back
  vim.cmd "normal! m'"
  if vim.fs.normalize(vim.api.nvim_buf_get_name(0)) ~= path then vim.cmd.edit(vim.fn.fnameescape(path)) end
  local first, last = lines_of(path, r)
  vim.api.nvim_win_set_cursor(0, { first, 0 })
  vim.cmd 'normal! zz'
  if opts.flash ~= false then flash(0, first, last) end
end

--- Follows the reference under the cursor; returns false when there's none
function M.follow(split)
  local r = M.cursor_ref()
  if not r then return false end
  M.open(r, { split = split })
  return true
end

-- Text of a reference ----------------------------------------------------------------------

--- Verses of `r` in `lang`: list of { ch, v, sub, to, text }, the language used (nil if absent)
function M.verses(r, lang)
  lang = data.lang_with(r.book, lang or r.lang or data.lang())
  local path = lang and data.file(r.book, lang)
  if not path then return {}, nil end
  local p = data.parse(path)
  local out = {}
  -- A lettered verse ("Est 1:1a") where the text has one; else ("Jn 3:16a", half a verse) the verse
  local pin_sub = r.v and r.sub and not r.v2 and p.at[r.ch .. ':' .. r.v .. r.sub] ~= nil
  for _, v in ipairs(p.list) do
    if r.v then
      if ref.contains(r, v.ch, v.v) and (not pin_sub or v.sub == r.sub) then table.insert(out, v) end
    elseif v.ch >= r.ch and v.ch <= (r.ch2 or r.ch) then
      table.insert(out, v)
    end
  end
  return out, lang
end

--- Reference `r` quoted: “text” (Jn 3:16)
function M.quote(r, lang)
  local verses, used = M.verses(r, lang)
  if not used or #verses == 0 then return end
  local parts = {}
  for _, v in ipairs(verses) do
    table.insert(parts, data.plain(v.text))
  end
  local q = { sr = { '„', '“' }, ru = { '«', '»' }, el = { '«', '»' } }
  local open, close = unpack(q[used:match '^[^-]+'] or { '“', '”' })
  return ('%s%s%s (%s)'):format(open, table.concat(parts, ' '), close, ref.format(r, used))
end

--- Yanks the quote of the reference under the cursor, of the verse at the cursor, or (visual)
--- of the verses in the selection
function M.yank(visual)
  local r
  if visual then
    local cv = M.cursor_verse()
    if not cv then return end
    local s, e = vim.fn.line 'v', vim.fn.line '.'
    if s > e then
      s, e = e, s
    end
    local p = data.parse(vim.api.nvim_buf_get_name(0))
    local first, last
    for _, v in ipairs(p.list) do
      if v.line >= s and v.line <= e then
        first = first or v
        last = v
      end
    end
    if not first then return end
    r = {
      book = cv.book,
      ch = first.ch,
      v = first.v,
      ch2 = last.ch ~= first.ch and last.ch or nil,
      v2 = (last.to or last.v) ~= first.v and (last.to or last.v) or nil,
      lang = cv.lang,
    }
    vim.api.nvim_feedkeys(vim.keycode '<Esc>', 'n', false)
  else
    r = M.cursor_ref()
    local cv = not r and M.cursor_verse()
    if cv and cv.v then r = { book = cv.book, ch = cv.ch, v = cv.v, sub = cv.sub, lang = cv.lang } end
  end
  if not r then return vim.notify('No verse or reference here', vim.log.levels.WARN) end
  local text = M.quote(r)
  if not text then return end
  vim.fn.setreg(vim.v.register, text)
  vim.notify('Yanked ' .. ref.format(r, r.lang or data.lang()))
end

-- Cross-references and footnotes -----------------------------------------------------------
-- Cross-references (data/xrefs.json) are verse ids, shown in whatever language is being read;
-- each set (the Serbian edition's, the English editions', OpenBible's) can be turned off.
-- Footnotes belong to their translation (data/<lang>.json).

--- Cross-references of a verse from the sets that are on: list of references, in set order,
--- each target once. `opts.sources` limits the sets; `opts.all` ignores which are on.
function M.verse_xrefs(book, ch, v, sub, opts)
  opts = opts or {}
  local by = data.xrefs().refs[('%s.%d.%s'):format(book, ch, v .. (sub or ''))]
  if not by then return {} end
  local out, seen = {}, {}
  for _, key in ipairs(data.XREF_ORDER) do
    if by[key] and (opts.all or data.xref_source_on(key)) then
      for _, id in ipairs(by[key]) do
        local r = not seen[id] and ref.from_id(id)
        if r then
          seen[id] = true
          r.source = key
          table.insert(out, r)
        end
      end
    end
  end
  return out
end

--- Footnotes of a verse in a language
function M.verse_notes(book, ch, v, sub, lang)
  local e = data.extras(lang)[('%s.%d.%s'):format(book, ch, v .. (sub or ''))]
  return e and e.notes or {}
end

-- Inline, OpenBible's are cut to its best-voted few (all of them are in <leader>bX and K)
local INLINE_OPENBIBLE = 8

--- `chunks` (text, hl) split into virtual lines no wider than `width`, after a `lead` sign
local function wrap_virt(lead, text, hl, width)
  local lines, cur = {}, ''
  for part in (text .. '; '):gmatch '(.-; )' do
    if cur ~= '' and vim.api.nvim_strwidth(cur .. part) > width then
      table.insert(lines, cur)
      cur = ''
    end
    cur = cur .. part
  end
  if cur ~= '' then table.insert(lines, cur) end
  local out = {}
  for i, l in ipairs(lines) do
    l = i == #lines and l:gsub(';%s*$', '') or l:gsub('%s+$', '')
    table.insert(out, { { i == 1 and lead or (' '):rep(vim.api.nvim_strwidth(lead)), 'BibleExtraSign' }, { l, hl } })
  end
  return out
end

--- Shows (or hides) the cross-references and footnotes under the verses of a Bible buffer
function M.render_extras(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns_extras, 0, -1)
  if not M.show_extras() then return end
  local book, lang = data.locate(vim.api.nvim_buf_get_name(buf))
  if not book then return end
  local win = vim.fn.bufwinid(buf)
  local width = math.max(40, (win ~= -1 and vim.api.nvim_win_get_width(win) or 80) - 10)
  for _, v in ipairs(data.parse(vim.api.nvim_buf_get_name(buf)).list) do
    local sub = v.sub ~= '' and v.sub or nil
    local lines = {}
    local refs, extra = {}, 0
    for _, r in ipairs(M.verse_xrefs(book, v.ch, v.v, sub)) do
      if r.source == 'openbible' and #refs >= INLINE_OPENBIBLE then
        extra = extra + 1
      else
        table.insert(refs, r)
      end
    end
    if #refs > 0 then
      local text = ref.format_list(refs, lang) .. (extra > 0 and ('; +' .. extra) or '')
      vim.list_extend(lines, wrap_virt('    ↪ ', text, 'BibleXref', width))
    end
    for _, n in ipairs(M.verse_notes(book, v.ch, v.v, sub, lang)) do
      table.insert(lines, { { '    ※ ', 'BibleExtraSign' }, { n, 'BibleNote' } })
    end
    if #lines > 0 then vim.api.nvim_buf_set_extmark(buf, ns_extras, v.line - 1, 0, { virt_lines = lines }) end
  end
end

local function rerender()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and data.locate(vim.api.nvim_buf_get_name(buf)) then M.render_extras(buf) end
  end
end

function M.show_extras() return data.state().extras == true end

function M.set_show_extras(on)
  data.state().extras = on
  data.save_state()
  rerender()
end

--- Turns the cross-reference sets on and off (a list; pick one to flip it, <Esc> when done)
function M.select_xref_sources()
  local sources = data.xrefs().sources or {}
  local keys = vim.tbl_filter(function(k) return sources[k] end, data.XREF_ORDER)
  vim.ui.select(keys, {
    prompt = 'Cross-references shown',
    format_item = function(k) return (data.xref_source_on(k) and '● ' or '○ ') .. sources[k] end,
  }, function(choice)
    if not choice then return end
    data.set_xref_source(choice, not data.xref_source_on(choice))
    rerender()
    vim.schedule(M.select_xref_sources)
  end)
end

--- Picker of the cross-references of the verse at the cursor (or the reference under it)
function M.xrefs()
  local cv = M.cursor_verse()
  local r = cv and cv.v and cv or M.cursor_ref()
  if not (r and r.v) then return vim.notify('No verse here', vim.log.levels.WARN) end
  local label = ref.format(r, data.lang())
  local targets = M.verse_xrefs(r.book, r.ch, r.v, r.sub)
  if #targets == 0 then
    local hidden = #M.verse_xrefs(r.book, r.ch, r.v, r.sub, { all = true })
    local notes = 0
    for _, l in ipairs(data.meta().lang_order) do
      notes = notes + #M.verse_notes(r.book, r.ch, r.v, r.sub, l)
    end
    local msg = 'No cross-references for ' .. label
    if hidden > 0 then
      msg = msg .. (' (%d in sets that are off: :Bible xrefs)'):format(hidden)
    elseif notes > 0 then
      msg = msg .. ('; it has %d footnote%s (K shows them)'):format(notes, notes == 1 and '' or 's')
    end
    return vim.notify(msg)
  end
  local names = data.xrefs().sources or {}
  local items = {}
  for _, t in ipairs(targets) do
    local verses, used = M.verses(t)
    local file = used and data.file(t.book, used)
    local text = verses[1] and data.plain(verses[1].text) or ''
    local tl = ref.format(t, data.lang())
    table.insert(items, {
      text = tl .. ' ' .. text,
      label = tl,
      ref = t,
      preview_text = text,
      -- Which edition printed the reference (the reference itself is shown in the reading language)
      source = t.source == 'openbible' and 'OpenBible' or ((names[t.source] or t.source):match '^%S+' .. ' ed.'),
      file = file,
      pos = file and { line_of(file, t), 0 } or nil,
    })
  end
  Snacks.picker {
    title = 'Cross-references · ' .. label,
    items = items,
    format = function(item)
      return {
        { ('%-16s'):format(item.label), 'SnacksPickerLabel' },
        { ('%-13s'):format(item.source), 'SnacksPickerComment' },
        { item.preview_text },
      }
    end,
    preview = 'file',
    confirm = function(picker, item)
      picker:close()
      if item then M.open(item.ref) end
    end,
  }
end

-- Hover ------------------------------------------------------------------------------------

--- Float with the reference (or verse at the cursor) in every language, plus its
--- cross-references and footnotes. Returns false when there's nothing here.
function M.hover()
  local r = M.cursor_ref()
  if not r then
    local cv = M.cursor_verse()
    if cv and cv.v then r = { book = cv.book, ch = cv.ch, v = cv.v, sub = cv.sub } end
  end
  if not r then return false end
  local lines = {}
  local notes = {}
  local families = {} -- Serbian Latin repeats the Cyrillic notes: once per language
  for _, lang in ipairs(data.meta().lang_order) do
    local verses = M.verses(r, lang)
    if data.book(r.book).has[lang] and #verses > 0 then
      if #lines > 0 then table.insert(lines, '') end
      table.insert(lines, ('**%s** · %s'):format(ref.format(r, lang), data.lang_name(lang)))
      for i, v in ipairs(verses) do
        if i > 12 then
          table.insert(lines, ('… %d more'):format(#verses - 12))
          break
        end
        local n = (#verses > 1 or r.v2) and ('%d%s. '):format(v.v, v.sub or '') or ''
        table.insert(lines, n .. v.text)
      end
      local first = verses[1]
      local family = lang:match '^[^-]+'
      if not families[family] then
        families[family] = true
        for _, n in ipairs(M.verse_notes(r.book, first.ch, first.v, first.sub ~= '' and first.sub or nil, lang)) do
          table.insert(notes, ('※ %s (%s)'):format(n, lang))
        end
      end
    end
  end
  local targets = r.v and M.verse_xrefs(r.book, r.ch, r.v, r.sub) or {}
  if #targets > 0 or #notes > 0 then
    table.insert(lines, '')
    table.insert(lines, '---')
    -- One line, in the reading language: <CR> on any of them follows it
    if #targets > 0 then table.insert(lines, '↪ ' .. ref.format_list(targets, data.lang())) end
    vim.list_extend(lines, notes)
  end
  vim.lsp.util.open_floating_preview(lines, 'markdown', { border = 'rounded', focus_id = 'bible-hover', max_width = 90, wrap = true })
  return true
end

-- Backlinks --------------------------------------------------------------------------------

local function vault_root()
  local ok, notes = pcall(require, 'config.notes')
  return ok and data.root() and notes.root(data.root()) or nil
end

--- Notes in the vault referring to the reference (or verse/chapter) at the cursor
function M.backlinks()
  local r = M.cursor_ref()
  local cv = not r and M.cursor_verse()
  if cv then r = { book = cv.book, ch = cv.ch, v = cv.v } end
  if not r then return false end
  local vault = vault_root()
  if not vault then return vim.notify('No vault', vim.log.levels.WARN) end
  -- Lines mentioning any name of the book (rg narrows; the parser decides)
  local names = {}
  for _, l in ipairs(data.meta().lang_order) do
    for _, n in ipairs(data.book(r.book).names[l] or {}) do
      names[vim.fn.escape(n, [[\.^$*+?()[]{}|-]]):gsub(' ', [[\s*]])] = true
    end
  end
  local pattern = table.concat(vim.tbl_keys(names), '|')
  local rel = data.root():sub(#vault + 2)
  local out = vim.system({ 'rg', '-n', '--no-heading', '-i', '-g', '*.md', '-g', '!' .. rel .. '/**', '-e', pattern }, { cwd = vault, text = true }):wait()
  local items = {}
  for _, l in ipairs(vim.split(out.stdout or '', '\n', { trimempty = true })) do
    local file, lnum, text = l:match '^(.-):(%d+):(.*)$'
    if file then
      for _, t in ipairs(ref.parse(text)) do
        local hit
        if t.book == r.book then
          if r.v then
            hit = ref.contains(t, r.ch, r.v)
          else
            hit = t.ch <= r.ch and (t.ch2 or t.ch) >= r.ch
          end
        end
        if hit then
          table.insert(items, { file = vault .. '/' .. file, pos = { tonumber(lnum), t.col }, text = file .. ' ' .. text, line = text })
          break
        end
      end
    end
  end
  local label = ref.format(r, data.lang())
  if #items == 0 then return vim.notify('No notes refer to ' .. label) end
  Snacks.picker { title = 'Notes on ' .. label, items = items, format = 'file' }
  return true
end

-- Normalising references -------------------------------------------------------------------

--- Rewrites the references in lines first..last (whole buffer by default) in one style:
--- the reading language's abbreviations ("Jn 3:16"; Serbian "Јн 3, 16"). Pinned ones keep their language.
function M.normalize(first, last, lang)
  lang = lang or data.lang()
  first, last = first or 1, last or vim.api.nvim_buf_line_count(0)
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local changed = 0
  for i, line in ipairs(lines) do
    local refs = ref.parse(line)
    for k = #refs, 1, -1 do
      local r = refs[k]
      if not r.cont and not r.link then
        local text = ref.format(r, r.lang or lang) .. (r.lang and (' (' .. r.lang .. ')') or '')
        if line:sub(r.col + 1, r.end_col) ~= text then
          line = line:sub(1, r.col) .. text .. line:sub(r.end_col + 1)
          changed = changed + 1
        end
      end
    end
    lines[i] = line
  end
  if changed > 0 then vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines) end
  vim.notify(('Normalized %d reference%s'):format(changed, changed == 1 and '' or 's'))
end

-- Language ---------------------------------------------------------------------------------

--- Switches the reading language; the Bible buffer in the current window follows, at the same verse
function M.set_lang(lang)
  data.set_lang(lang)
  local cv = M.cursor_verse()
  if cv and cv.lang ~= lang and data.book(cv.book).has[lang] then
    M.open({ book = cv.book, ch = cv.ch, v = cv.v, sub = cv.sub }, { lang = lang, flash = false })
  end
  vim.notify('Bible in ' .. data.lang_name(lang))
end

function M.select_lang(on_choice)
  local meta = data.meta()
  if not meta then return end
  vim.ui.select(meta.lang_order, {
    prompt = 'Bible language',
    format_item = function(l) return (l == data.lang() and '● ' or '  ') .. data.lang_name(l) .. ' (' .. l .. ')' end,
  }, function(choice)
    if choice then (on_choice or M.set_lang)(choice) end
  end)
end

-- Keys in notes ----------------------------------------------------------------------------

--- Buffer-local `lhs` that runs `fn` and falls back to whatever `lhs` was before (obsidian.nvim's
--- <CR>, the LSP's gd/grr/K) when `fn` returns false. Safe to call again after others remap it.
function M.wrap_key(buf, mode, lhs, fn, desc)
  local current = vim.fn.maparg(lhs, mode, false, true) ---@type table
  if current.desc and current.desc:find '^Bible: ' and current.buffer == 1 then return end
  local prev = (current.buffer == 1) and current or nil
  vim.keymap.set(mode, lhs, function()
    if fn() ~= false then return end
    if prev and prev.callback then
      local res = prev.callback()
      if prev.expr == 1 and type(res) == 'string' then vim.api.nvim_feedkeys(vim.keycode(res), prev.noremap == 1 and 'n' or 'm', false) end
    elseif prev and prev.rhs then
      local keys = prev.expr == 1 and vim.api.nvim_eval(prev.rhs) or prev.rhs
      vim.api.nvim_feedkeys(vim.keycode(keys), prev.noremap == 1 and 'n' or 'm', false)
    else
      vim.api.nvim_feedkeys(vim.keycode(lhs), 'n', false)
    end
  end, { buffer = buf, desc = 'Bible: ' .. desc })
end

-- Highlighting references in notes ---------------------------------------------------------

vim.api.nvim_set_hl(0, 'BibleRef', { default = true, link = '@markup.link' })
vim.api.nvim_set_hl(0, 'BibleXref', { default = true, link = 'Comment' })
vim.api.nvim_set_hl(0, 'BibleNote', { default = true, link = 'Comment' })
vim.api.nvim_set_hl(0, 'BibleExtraSign', { default = true, link = 'NonText' })
vim.api.nvim_set_hl(0, 'BibleBlockId', { default = true, link = 'NonText' })

local highlight_bufs = {}
function M.highlight_refs(buf) highlight_bufs[buf] = true end

vim.api.nvim_set_decoration_provider(ns, {
  on_win = function(_, _, buf) return highlight_bufs[buf] == true and vim.api.nvim_buf_is_loaded(buf) end,
  on_line = function(_, _, buf, row)
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    if not line or not line:find '%d' or #line > 2000 then return end
    for _, r in ipairs(ref.parse(line)) do
      vim.api.nvim_buf_set_extmark(buf, ns, row, r.col, { end_col = r.end_col, hl_group = 'BibleRef', ephemeral = true })
    end
  end,
})

--- Hides the block ids ending verse lines (" ^3-16", for Obsidian links), as Obsidian does
--- (dimmed on the cursor line, where Neovim shows concealed text)
function M.conceal_block_ids(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns_ids, 0, -1)
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local s = line:find(data.BLOCK_ID)
    if s then vim.api.nvim_buf_set_extmark(buf, ns_ids, i - 1, s - 1, { end_col = #line, conceal = '', hl_group = 'BibleBlockId' }) end
  end
end

-- Setup ------------------------------------------------------------------------------------

function M.setup()
  local group = vim.api.nvim_create_augroup('bible', { clear = true })
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = group,
    pattern = '*.md',
    callback = function(ev)
      if not data.locate(ev.match) then return end
      -- Scripture isn't edited by accident; :set noreadonly if it really must be
      vim.bo[ev.buf].readonly = true
      if not vim.b[ev.buf].bible_rendered then
        vim.b[ev.buf].bible_rendered = true
        M.render_extras(ev.buf)
        M.conceal_block_ids(ev.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(ev) highlight_bufs[ev.buf] = nil end,
  })

  vim.api.nvim_create_user_command('Bible', function(cmd)
    local sub, rest = cmd.args:match '^(%S*)%s*(.*)$'
    if sub == '' then return require('config.bible.picker').go() end
    if sub == 'lang' then
      if rest ~= '' and data.meta().langs[rest] then return M.set_lang(rest) end
      return M.select_lang()
    end
    if sub == 'xrefs' then return M.select_xref_sources() end
    if sub == 'normalize' then return M.normalize(cmd.line1, cmd.line2, rest ~= '' and rest or nil) end
    if sub == 'follow' then return require('config.bible.follow').toggle() end
    if sub == 'search' then return require('config.bible.picker').search(rest) end
    local r = ref.parse_one(cmd.args)
    if not r then
      -- A book alone: "jn", "1 kor"
      local id = ref.book(cmd.args)
      r = id and { book = id, ch = 1 }
    end
    if not r then return vim.notify('Not a reference: ' .. cmd.args, vim.log.levels.WARN) end
    M.open(r)
  end, {
    nargs = '*',
    range = '%',
    desc = 'Open a Bible reference (:Bible jn 3:16), or :Bible lang|normalize|follow|search|xrefs',
    complete = function(arg, line)
      if line:match '^%S+%s+%S*$' then
        return vim.tbl_filter(function(s) return s:find(arg, 1, true) == 1 end, { 'lang', 'normalize', 'follow', 'search', 'xrefs' })
      end
      if line:match '^%S+%s+lang%s+' then return data.meta().lang_order end
      return {}
    end,
  })
end

return M
