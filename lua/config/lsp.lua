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

-- Highlight other uses of the symbol under the cursor after a short pause
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('lsp-highlight', { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not (client and client:supports_method('textDocument/documentHighlight', args.buf)) then return end

    local group = vim.api.nvim_create_augroup('lsp-highlight-' .. args.buf, { clear = true })
    vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, { group = group, buffer = args.buf, callback = vim.lsp.buf.document_highlight })
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, { group = group, buffer = args.buf, callback = vim.lsp.buf.clear_references })
    vim.api.nvim_create_autocmd('LspDetach', {
      group = group,
      buffer = args.buf,
      callback = function()
        vim.lsp.buf.clear_references()
        vim.api.nvim_clear_autocmds { group = group, buffer = args.buf }
      end,
    })
  end,
})
