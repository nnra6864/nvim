return {
  -- Only provides the server configs in lsp/; they're enabled in config/lsp.lua
  { 'neovim/nvim-lspconfig', lazy = false },
  {
    -- Teaches lua_ls about the Neovim API, but only inside Neovim config/plugin files
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = { library = { { path = '${3rd}/luv/library', words = { 'vim%.uv' } } } },
  },
}
