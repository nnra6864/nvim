-- The follower: a split with another translation that follows whichever window you're reading
-- in, verse by verse, lined up with it on screen. In a note it follows the reference under the
-- cursor; elsewhere it waits (the winbar says so) and picks up again when you're back in a
-- Bible book. It stops only when it's closed.
local data = require 'config.bible.data'

local M = {}

local state = { win = nil, timer = nil, syncing = false, shown = nil }

function M.win()
  if state.win and vim.api.nvim_win_is_valid(state.win) then return state.win end
  state.win = nil
end

--- The follower's language: remembered; never the reading language when there's another
function M.lang()
  local l = data.state().follow_lang
  if l and data.meta().langs[l] then return l end
  return data.next_lang(data.lang(), 1)
end

function M.set_lang(lang)
  data.state().follow_lang = lang
  data.save_state()
  state.shown = nil
  M.sync(true)
end

local function bible() return require 'config.bible' end

local function winbar(text, paused)
  local win = M.win()
  if not win then return end
  local hl = paused and '%#Comment#' or '%#WinBar#'
  vim.wo[win].winbar = hl .. ' ⇄ ' .. data.lang_name(M.lang()) .. (text and ('  ·  ' .. text) or '') .. (paused and '  (waiting)' or '')
end

--- Screen rows from the top of `win` to line `lnum` (wrapped lines count their rows)
local function rows_above(win, lnum)
  local top = vim.fn.line('w0', win)
  if lnum <= top then return 0 end
  local ok, h = pcall(vim.api.nvim_win_text_height, win, { start_row = top - 1, end_row = lnum - 2 })
  return ok and h.all or (lnum - top)
end

--- Shows reference `r` (from window `src`, when it's a Bible window) in the follower
local function show(r, src)
  local win = M.win()
  if not win then return end
  local lang = data.lang_with(r.book, M.lang())
  local path = lang and data.file(r.book, lang)
  if not path then return end
  state.syncing = true
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) ~= path then
    vim.api.nvim_win_call(win, function() vim.cmd('keepjumps keepalt edit ' .. vim.fn.fnameescape(path)) end)
  end
  local line = bible().line_of(path, r)
  -- r.line: the verse's line in the window being read
  local rows = src and r.line and rows_above(src, r.line) or nil
  vim.api.nvim_win_call(win, function()
    vim.api.nvim_win_set_cursor(win, { line, 0 })
    if rows then
      -- Same screen row as in the window being read: walk up until the rows above match
      local top = line
      while top > 1 do
        local ok, h = pcall(vim.api.nvim_win_text_height, win, { start_row = top - 2, end_row = line - 2 })
        if not ok or h.all > rows then break end
        top = top - 1
      end
      vim.fn.winrestview { topline = top, lnum = line, col = 0 }
    else
      vim.cmd 'normal! zz'
    end
  end)
  state.syncing = false
  local label = require('config.bible.ref').format(r, lang)
  winbar(label .. (lang ~= M.lang() and ('  (' .. data.lang_name(lang) .. ')') or ''), false)
  state.shown = r
end

--- Syncs the follower to the current window (debounced unless `now`)
function M.sync(now)
  if not M.win() or state.syncing then return end
  local function run()
    local win = M.win()
    if not win then return end
    local cur = vim.api.nvim_get_current_win()
    if cur == win or vim.api.nvim_win_get_config(cur).relative ~= '' then return end
    local cv = bible().cursor_verse(cur)
    if cv then return show(cv, cur) end
    local r = bible().cursor_ref(cur)
    if r then return show(r) end
    -- Not in the Bible: keep showing the last verse, marked as waiting
    if state.shown then
      winbar(require('config.bible.ref').format(state.shown, data.lang_with(state.shown.book, M.lang())), true)
    end
  end
  if now then return run() end
  state.timer = state.timer or vim.uv.new_timer()
  state.timer:stop()
  state.timer:start(25, 0, vim.schedule_wrap(run))
end

function M.open(lang)
  if lang then
    data.state().follow_lang = lang
    data.save_state()
  end
  if M.win() then return M.sync(true) end
  local src = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(src).relative ~= '' then src = bible().target_win() end
  vim.api.nvim_set_current_win(src)
  vim.cmd 'rightbelow vsplit'
  state.win = vim.api.nvim_get_current_win()
  vim.w[state.win].bible_follower = true
  vim.wo[state.win].cursorline = true
  vim.wo[state.win].winfixbuf = false
  vim.api.nvim_set_current_win(src)
  local group = vim.api.nvim_create_augroup('bible-follow', { clear = true })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'WinScrolled', 'BufEnter', 'WinEnter', 'WinResized' }, {
    group = group,
    callback = function() M.sync() end,
  })
  vim.api.nvim_create_autocmd('User', { group = group, pattern = 'BibleLang', callback = function() M.sync(true) end })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    callback = function(ev)
      if tonumber(ev.match) == state.win then M.stop() end
    end,
  })
  -- Before anything has been read: the book in the current window, else John 1
  local cv = bible().cursor_verse(src)
  local r = cv or bible().cursor_ref(src)
  if r then
    show(r, cv and src or nil)
  else
    show { book = 'JHN', ch = 1, v = 1 }
    winbar('John 1', true)
  end
end

--- Ends following (the split stays if it's still open; :q closes it)
function M.stop()
  pcall(vim.api.nvim_del_augroup_by_name, 'bible-follow')
  if state.timer then state.timer:stop() end
  local win = M.win()
  if win then vim.wo[win].winbar = '' end
  state.win, state.shown = nil, nil
end

function M.toggle(lang)
  local win = M.win()
  if win then
    M.stop()
    pcall(vim.api.nvim_win_close, win, false)
  else
    M.open(lang)
  end
end

--- Picks the follower's language (and opens it when it's closed)
function M.select_lang()
  bible().select_lang(function(l)
    if M.win() then
      M.set_lang(l)
    else
      M.open(l)
    end
  end)
end

return M
