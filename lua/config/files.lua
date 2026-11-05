-- Renaming and moving files. Language servers are told first, so they can update imports,
-- or links to the note in Obsidian vaults. The buffer is renamed in place, keeping undo history.
local M = {}

local function tell_servers(method, changes, request)
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client:supports_method(method) then
      if request then
        local resp = client:request_sync(method, changes, 1000)
        if resp and resp.result then
          vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
          -- The edits land in buffers (other notes, importing files); save them like the move itself
          local uris = vim.tbl_keys(resp.result.changes or {})
          for _, change in ipairs(resp.result.documentChanges or {}) do
            if change.textDocument then table.insert(uris, change.textDocument.uri) end
          end
          for _, uri in ipairs(uris) do
            vim.api.nvim_buf_call(vim.uri_to_bufnr(uri), function() vim.cmd 'silent update' end)
          end
        end
      else
        client:notify(method, changes)
      end
    end
  end
end

function M.move(from, to)
  from, to = vim.fs.normalize(vim.fn.fnamemodify(from, ':p')), vim.fs.normalize(vim.fn.fnamemodify(to, ':p'))
  if from == to then return end
  if vim.uv.fs_stat(to) then return vim.notify('Already exists: ' .. to, vim.log.levels.ERROR) end

  local changes = { files = { { oldUri = vim.uri_from_fname(from), newUri = vim.uri_from_fname(to) } } }
  local unsaved = {}
  for _, info in ipairs(vim.fn.getbufinfo { bufmodified = 1 }) do
    unsaved[info.bufnr] = true
  end
  tell_servers('workspace/willRenameFiles', changes, true)
  vim.fn.mkdir(vim.fs.dirname(to), 'p')

  local buf = vim.fn.bufnr(from)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    -- Write under the new name, then remove the old file; unsaved edits come along
    vim.api.nvim_buf_set_name(buf, to)
    vim.api.nvim_buf_call(buf, function() vim.cmd 'silent write!' end)
    os.remove(from)
    -- :file leaves an unlisted buffer behind for the old name
    local old = vim.fn.bufnr(from)
    if old ~= -1 then vim.api.nvim_buf_delete(old, { force = true }) end
  elseif vim.fn.rename(from, to) ~= 0 then
    return vim.notify('Failed to move ' .. from, vim.log.levels.ERROR)
  end

  tell_servers('workspace/didRenameFiles', changes)
  -- Some servers (obsidian.nvim's) send their edits only after hearing about the rename.
  -- Save buffers they changed, leaving alone any that already had unsaved edits
  vim.defer_fn(function()
    for _, info in ipairs(vim.fn.getbufinfo { bufmodified = 1 }) do
      if not unsaved[info.bufnr] then vim.api.nvim_buf_call(info.bufnr, function() vim.cmd 'silent update' end) end
    end
  end, 500)
end

--- Prompts for a new name (or path, relative to the file's folder)
function M.rename()
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then return end
  vim.ui.input({ prompt = 'Rename to: ', default = vim.fs.basename(file), completion = 'file' }, function(name)
    if name and name ~= '' then M.move(file, vim.fs.joinpath(vim.fs.dirname(file), name)) end
  end)
end

--- Picks a folder of the vault, git repo or cwd (fd skips hidden and ignored ones) to move into
function M.move_to_folder()
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then return end
  local root = require('config.notes').root(file) or vim.fs.root(file, '.git') or vim.fn.getcwd()
  Snacks.picker.pick {
    title = 'Move to folder',
    format = 'file',
    finder = function()
      local items = { { text = './', file = root .. '/', dir = true } }
      for _, dir in ipairs(vim.fn.systemlist { 'fd', '--type', 'd', '--base-directory', root }) do
        table.insert(items, { text = dir, file = root .. '/' .. dir, dir = true })
      end
      return items
    end,
    confirm = function(picker, item)
      picker:close()
      if item then M.move(file, vim.fs.joinpath(item.file, vim.fs.basename(file))) end
    end,
  }
end

return M
