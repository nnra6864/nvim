local group = vim.api.nvim_create_augroup('config', { clear = true })

vim.api.nvim_create_autocmd('TextYankPost', {
  group = group,
  desc = 'Highlight yanked text',
  callback = function() vim.hl.on_yank() end,
})

-- Notes in Obsidian vaults save themselves like in the app: a second after typing stops, and
-- right away on leaving insert mode or the buffer, or when Neovim loses focus. Files outside vaults are untouched.
local timers = {}

local function in_vault(buf)
  if vim.b[buf].in_vault == nil then
    local name = vim.api.nvim_buf_get_name(buf)
    vim.b[buf].in_vault = vim.bo[buf].buftype == '' and name ~= '' and require('config.notes').root(name) ~= nil
  end
  return vim.b[buf].in_vault
end

local function autosave(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].modified or not in_vault(buf) then return end
  if vim.bo[buf].readonly or not vim.bo[buf].modifiable then return end
  local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd 'silent lockmarks update' end)
  if not ok then vim.notify('Autosave failed: ' .. err, vim.log.levels.WARN) end
end

vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
  group = group,
  desc = 'Autosave vault notes after typing stops',
  callback = function(ev)
    if not in_vault(ev.buf) then return end
    timers[ev.buf] = timers[ev.buf] or vim.uv.new_timer()
    timers[ev.buf]:start(1000, 0, vim.schedule_wrap(function() autosave(ev.buf) end))
  end,
})

vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave', 'FocusLost' }, {
  group = group,
  desc = 'Autosave vault notes',
  callback = function(ev) autosave(ev.buf) end,
})

vim.api.nvim_create_autocmd({ 'BufFilePost', 'BufWipeout' }, {
  group = group,
  desc = 'Forget autosave state of renamed or closed buffers',
  callback = function(ev)
    if ev.event == 'BufFilePost' then vim.b[ev.buf].in_vault = nil end
    if ev.event == 'BufWipeout' and timers[ev.buf] then
      timers[ev.buf]:close()
      timers[ev.buf] = nil
    end
  end,
})

-- Opening a directory (`nvim .`, `:e dir/`) runs open_directory instead of showing a listing.
-- Change it to pick something else, e.g. `require('yazi').yazi(nil, dir)` for yazi,
-- or `vim.cmd.lcd(dir)` first to also make it the working directory
vim.g.loaded_netrwPlugin = 1

local function open_directory(dir) Snacks.picker.files { cwd = dir } end

vim.api.nvim_create_autocmd('BufEnter', {
  group = group,
  desc = 'Open directories with open_directory',
  callback = function(ev)
    local dir = vim.api.nvim_buf_get_name(ev.buf)
    -- BufEnter can fire more than once for the same directory buffer; open it only the first time
    if vim.b[ev.buf].directory_opened or dir == '' or vim.fn.isdirectory(dir) == 0 then return end
    vim.b[ev.buf].directory_opened = true
    -- The empty directory buffer goes away once a picked file replaces it
    vim.bo[ev.buf].bufhidden = 'wipe'
    vim.schedule(function() open_directory(vim.fs.normalize(dir)) end)
  end,
})
