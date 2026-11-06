-- blink.cmp source: inside [[ in a vault note, suggests links to notes that don't exist yet
-- but are linked from somewhere in the vault, like the Obsidian app does.
-- Existing notes are suggested by obsidian.nvim; this only adds the unresolved ones.
local notes = require 'config.notes'

local source = {}

function source.new() return setmetatable({}, { __index = source }) end

function source:enabled() return vim.bo.filetype == 'markdown' and notes.root(vim.api.nvim_buf_get_name(0)) ~= nil end

function source:get_trigger_characters() return { '[' } end

-- Per vault: { time, items }. Rescanned when older than a few seconds or after a save.
local cache = {}
vim.api.nvim_create_autocmd('BufWritePost', {
  group = vim.api.nvim_create_augroup('unresolved-links', { clear = true }),
  pattern = '*.md',
  callback = function(ev)
    local vault = notes.root(ev.match)
    if vault then cache[vault] = nil end
  end,
})

--- Link targets in the vault with no matching file, and how many notes link to each
local function scan(vault, done)
  local cached = cache[vault]
  if cached and vim.uv.now() - cached.time < 5000 then return done(cached.targets) end

  local files, links
  local function finish()
    if not files or not links then return end
    -- Links resolve by name or by path, with or without .md, ignoring case
    local exists = {}
    for _, file in ipairs(files) do
      file = file:lower()
      local name = vim.fs.basename(file)
      exists[file], exists[name] = true, true
      exists[(file:gsub('%.md$', ''))], exists[(name:gsub('%.md$', ''))] = true, true
    end
    local targets, seen = {}, {}
    for _, line in ipairs(links) do
      local note, target = line:match '^(.-):%[%[(.*)$'
      target = target and vim.trim(target)
      if target and target ~= '' and not exists[target:lower()] then
        local key = target:lower()
        if not seen[key] then
          seen[key] = { name = target, notes = {} }
          table.insert(targets, seen[key])
        end
        seen[key].notes[note] = true
      end
    end
    cache[vault] = { time = vim.uv.now(), targets = targets }
    done(targets)
  end

  local function lines(out) return vim.split(out.stdout or '', '\n', { trimempty = true }) end
  vim.system({ 'rg', '--files' }, { cwd = vault, text = true }, function(out)
    files = lines(out)
    finish()
  end)
  -- Target of each [[link]], up to an alias (|), heading (#) or block (^)
  vim.system({ 'rg', '-o', '--no-line-number', '--with-filename', '-g', '*.md', [[\[\[[^\]|#^\n]+]] }, { cwd = vault, text = true }, function(out)
    links = lines(out)
    finish()
  end)
end

function source:get_completions(ctx, callback)
  local col = ctx.cursor[2]
  local before, after = ctx.line:sub(1, col), ctx.line:sub(col + 1)
  local query = before:match '%[%[([^%[%]|#^]*)$'
  local vault = notes.root(vim.api.nvim_buf_get_name(ctx.bufnr))
  if not query or not vault then
    callback { items = {}, is_incomplete_forward = false, is_incomplete_backward = false }
    return function() end
  end

  -- Replaces from [[ up to the cursor, and the ]] after it if it's already there
  local line = ctx.cursor[1] - 1
  local range = {
    start = { line = line, character = col - #query - 2 },
    ['end'] = { line = line, character = after:sub(1, 2) == ']]' and col + 2 or col },
  }

  scan(vault, function(targets)
    vim.schedule(function()
      local items = {}
      for _, target in ipairs(targets) do
        local linked_from = vim.tbl_map(function(n) return '- ' .. n:gsub('%.md$', '') end, vim.tbl_keys(target.notes))
        table.sort(linked_from)
        table.insert(items, {
          label = target.name,
          labelDetails = { description = 'not created' },
          filterText = '[[' .. target.name,
          kind = vim.lsp.protocol.CompletionItemKind.Reference,
          textEdit = { newText = '[[' .. target.name .. ']]', range = range },
          documentation = { kind = 'markdown', value = 'Not created yet. Linked from:\n' .. table.concat(linked_from, '\n') },
        })
      end
      callback { items = items, is_incomplete_forward = false, is_incomplete_backward = false }
    end)
  end)
  return function() end
end

return source
