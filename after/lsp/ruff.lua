return {
  -- ty provides hover; ruff's would only duplicate it
  on_attach = function(client) client.server_capabilities.hoverProvider = false end,
}
