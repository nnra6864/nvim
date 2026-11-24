return {
  -- Home is a git repo (dotfiles), so a Lua file outside any project would get it as its
  -- workspace, which lua_ls refuses to index. Such files get their own folder instead
  -- (no root at all isn't possible: Neovim then falls back to root_markers, finding home again).
  root_dir = function(buf, on_dir)
    local home = vim.fs.normalize '~'
    local root = vim.fs.root(buf, vim.lsp.config.lua_ls.root_markers)
    if root == home then root = vim.fs.dirname(vim.api.nvim_buf_get_name(buf)) end
    -- A file right in home has no folder of its own to use
    if root ~= home then on_dir(root) end
  end,
}
