-- Obsidian vaults and notes. A vault is any directory containing .obsidian, so nothing is
-- hardcoded; the last vault used is remembered (per machine) for opening notes from elsewhere.
local M = {}

local last_vault_file = vim.fn.stdpath 'state' .. '/obsidian-vault'

--- Vault containing `path` (a file or directory), if any
function M.root(path)
  if not path or path == '' then return end
  return vim.fs.root(path, '.obsidian')
end

function M.remember(vault) pcall(vim.fn.writefile, { vault }, last_vault_file) end

--- Vault of the current file, else of the cwd, else the last one used
function M.current()
  local file = vim.bo.buftype == '' and vim.api.nvim_buf_get_name(0) or ''
  local vault = M.root(file) or M.root(vim.fn.getcwd())
  if vault then return vault end
  local ok, lines = pcall(vim.fn.readfile, last_vault_file)
  if ok and lines[1] and vim.uv.fs_stat(lines[1] .. '/.obsidian') then return lines[1] end
end

-- Folders and formats from the vault's own Obsidian settings, so every vault behaves the way
-- it's set up in the app (and no folder gets created in a vault that doesn't use it)
local function vault_settings(vault)
  local function json(name)
    local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(vault .. '/.obsidian/' .. name), '\n')) end)
    return ok and type(data) == 'table' and data or {}
  end
  local app, templates = json 'app.json', json 'templates.json'
  return {
    templates = { folder = templates.folder or vim.NIL, date_format = templates.dateFormat, time_format = templates.timeFormat },
    attachments = { folder = app.attachmentFolderPath },
  }
end

--- Loads obsidian.nvim (if needed) and registers `vault` with it.
--- obsidian.nvim only resolves workspaces once, at setup, so vaults opened later are added here.
function M.activate(vault)
  M.remember(vault)
  require('lazy').load { plugins = { 'obsidian.nvim' } }
  local Workspace = require 'obsidian.workspace'
  local real = vim.uv.fs_realpath(vault) or vault
  local ws
  for _, w in ipairs(Obsidian.workspaces) do
    if tostring(w.root) == real then ws = w end
  end
  if not ws then
    ws = Workspace.new { name = vim.fn.fnamemodify(vault, ':~'), path = vault }
    if not ws then return end
    table.insert(Obsidian.workspaces, ws)
  end
  if not ws.overrides then
    ws.overrides = vault_settings(vault)
    if ws == Obsidian.workspace then Workspace.set(ws) end
  end
  return ws
end

local function frontmatter(tags)
  local lines = { '---', 'created: ' .. os.date '%Y-%m-%d %H:%M', 'tags:' }
  for _, tag in ipairs(tags) do
    table.insert(lines, '  - ' .. tag)
  end
  vim.list_extend(lines, { 'aliases:', '---' })
  return lines
end

-- Reads from the buffer when the file is open, so unsaved edits aren't lost
local function read(path)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then return vim.api.nvim_buf_get_lines(buf, 0, -1, false) end
  return vim.fn.readfile(path)
end

local function write(path, lines)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_call(buf, function() vim.cmd 'silent write' end)
  else
    vim.fn.writefile(lines, path)
  end
end

--- Checklist carry-over --------------------------------------------------------------------
-- The note body is parsed into a tree of list items by indentation. Splitting a tree gives
-- what stays (done) and what moves to the new note (todo):
--   [x] item          stays, with everything under it
--   [ ] item          moves, with everything under it, unless it has subtasks:
--   [ ] with subtasks done subtasks stay under a [x] copy, open ones move under a [ ] copy;
--                     once all subtasks are done the item itself counts as done
-- Lines without a checkbox (notes under a task) follow their parent; other text stays.

local function parse(lines)
  local root = { indent = -1, children = {} }
  local stack = { root }
  for _, line in ipairs(lines) do
    local ws, bullet, check, rest = line:match '^(%s*)([-*+] )%[(.)%](.*)$'
    if not ws then
      ws, bullet, rest = line:match '^(%s*)([-*+] )(.*)$'
    end
    local width = #(line:match('^%s*'):gsub('\t', '    '))
    if ws then
      while stack[#stack].indent >= width do
        table.remove(stack)
      end
      local item = { indent = width, ws = ws, bullet = bullet, check = check, rest = rest, extra = {}, children = {} }
      table.insert(stack[#stack].children, item)
      table.insert(stack, item)
    elseif line:match '%S' and #stack > 1 and width > stack[#stack].indent then
      table.insert(stack[#stack].extra, line) -- wrapped/continued text of the item above
    else
      stack = { root }
      table.insert(root.children, { text = line, children = {} })
    end
  end
  return root.children
end

local function has_task(item)
  if item.check then return true end
  for _, child in ipairs(item.children) do
    if has_task(child) then return true end
  end
  return false
end

local function copy(item, check, children)
  local new = vim.tbl_extend('force', item, { children = children })
  new.check = check
  return new
end

--- Returns the part that stays and the part that moves (either may be nil)
local function split(item)
  if item.text or (item.check and item.check ~= ' ') then return item, nil end

  local parts, any_task, any_todo = {}, false, false
  for _, child in ipairs(item.children) do
    if has_task(child) then
      local done, todo = split(child)
      any_task, any_todo = true, any_todo or todo ~= nil
      table.insert(parts, { done = done, todo = todo })
    else
      table.insert(parts, { note = child })
    end
  end

  if not any_task then
    if item.check == ' ' then return nil, item end
    return item, nil
  end

  local done, todo = {}, {}
  for _, part in ipairs(parts) do
    if part.note then
      table.insert(any_todo and todo or done, part.note)
    else
      table.insert(done, part.done)
      table.insert(todo, part.todo)
    end
  end
  return #done > 0 and copy(item, item.check and 'x', done) or nil, any_todo and copy(item, item.check, todo) or nil
end

local function render(items, out)
  for _, item in ipairs(items) do
    if item.text then
      table.insert(out, item.text)
    else
      table.insert(out, item.ws .. item.bullet .. (item.check and '[' .. item.check .. ']' or '') .. item.rest)
      vim.list_extend(out, item.extra)
      render(item.children, out)
    end
  end
  return out
end

--- Splits a note into the lines it keeps and the open tasks to carry over
function M.carry_over(lines)
  local head = {}
  if lines[1] == '---' then
    for i = 2, #lines do
      if lines[i] == '---' then
        head = vim.list_slice(lines, 1, i)
        lines = vim.list_slice(lines, i + 1)
        break
      end
    end
  end
  local keep, move = {}, {}
  for _, item in ipairs(parse(lines)) do
    local done, todo = split(item)
    table.insert(keep, done)
    table.insert(move, todo)
  end
  return vim.list_extend(head, render(keep, {})), render(move, {})
end

--- Commands ----------------------------------------------------------------------------------

local stamp = '^%d%d%d%d%-%d%d%-%d%d %d%d%-%d%d'

--- TODO notes in the vault root, oldest first
local function todos(vault)
  local list = {}
  for file, type in vim.fs.dir(vault) do
    if type == 'file' and file:match(stamp .. ' TODO%.md$') then table.insert(list, file) end
  end
  table.sort(list)
  return list
end

--- Opens the latest TODO note, or with `step` the next (1) or previous (-1) one from this note
function M.todo(step)
  local vault = M.current()
  if not vault then return vim.notify('Not in an Obsidian vault, and none used before', vim.log.levels.WARN) end
  local list, target = todos(vault), nil
  if #list == 0 then return vim.notify 'No TODO notes yet' end
  if not step then
    target = list[#list]
  else
    local here = vim.fn.expand '%:t'
    for i = step > 0 and 1 or #list, step > 0 and #list or 1, step do
      if (step > 0 and list[i] > here) or (step < 0 and list[i] < here) then
        target = list[i]
        break
      end
    end
    if not target then return vim.notify(step > 0 and 'Already at the latest TODO' or 'Already at the oldest TODO') end
  end
  vim.cmd.edit(vim.fn.fnameescape(vault .. '/' .. target))
end

--- New note named after the current time, like the Obsidian setup.
--- `todo` also moves the open tasks of the latest TODO note into it.
function M.new(todo)
  local vault = M.current()
  if not vault then return vim.notify('Not in an Obsidian vault, and none used before', vim.log.levels.WARN) end

  local name = os.date '%Y-%m-%d %H-%M' .. (todo and ' TODO' or '') .. '.md'
  local path = vault .. '/' .. name
  if vim.uv.fs_stat(path) then return vim.cmd.edit(vim.fn.fnameescape(path)) end

  local lines = frontmatter(todo and { 'note', 'todo' } or { 'note' })
  local header = #lines
  if todo then
    local list = todos(vault)
    local previous = list[#list]
    if previous then
      local keep, move = M.carry_over(read(vault .. '/' .. previous))
      write(vault .. '/' .. previous, keep)
      vim.list_extend(lines, move)
      -- Open items under a task marked done aren't carried over
      local left = #vim.tbl_filter(function(line) return line:match '^%s*[-*+] %[ %]' end, keep)
      if left > 0 then
        vim.notify(('%d unfinished item(s) stayed in %s, under tasks marked done'):format(left, previous), vim.log.levels.WARN)
      end
    end
  end
  -- An empty line to start typing on
  if #lines == header then table.insert(lines, '') end

  vim.fn.writefile(lines, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.api.nvim_win_set_cursor(0, { #lines, 0 })
end

return M
