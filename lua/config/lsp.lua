-- Server configs come from nvim-lspconfig; local overrides go in after/lsp/<name>.lua
-- (after/, because lspconfig's own lsp/ files would otherwise override them).
-- Servers that aren't installed are skipped, so the config works on machines missing some.
local servers = {
  'bashls',
  'clangd',
  'fish_lsp',
  'lua_ls',
  'marksman',
  'roslyn_ls',
  'ruff',
  'tinymist',
  'ty',
  'yamlls',
  'zls',
}

-- `dotnet tool install --global` puts roslyn here, and it's often not on PATH
local dotnet_tools = vim.fs.normalize '~/.dotnet/tools'
if vim.uv.fs_stat(dotnet_tools) then vim.env.PATH = dotnet_tools .. ':' .. vim.env.PATH end

for _, name in ipairs(servers) do
  local cmd = vim.lsp.config[name].cmd
  if type(cmd) == 'function' or vim.fn.executable(cmd[1]) == 1 then vim.lsp.enable(name) end
end

vim.diagnostic.config {
  severity_sort = true,
  virtual_text = true,
  float = { source = 'if_many' },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },
  jump = {
    on_jump = function(_, bufnr) vim.diagnostic.open_float { bufnr = bufnr, scope = 'cursor', focus = false } end,
  },
}

-- Server progress ("Loading workspace", indexing, ...) as a single notification that updates in place
vim.api.nvim_create_autocmd('LspProgress', {
  group = vim.api.nvim_create_augroup('lsp-progress', { clear = true }),
  callback = function(ev)
    local status = vim.lsp.status()
    -- Empty once every server is done; the notification is removed instead of left blank
    if status == '' then return Snacks.notifier.hide 'lsp_progress' end
    local done = ev.data.params.value.kind == 'end'
    vim.notify(status, vim.log.levels.INFO, {
      id = 'lsp_progress',
      title = 'LSP',
      icon = done and ' ' or '󰔟 ',
    })
  end,
})
