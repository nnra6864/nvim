-- Notes in Obsidian vaults get links, completion and renames from obsidian.nvim instead
return {
  root_dir = function(buf, on_dir)
    local file = vim.api.nvim_buf_get_name(buf)
    if require('config.notes').root(file) then return end
    on_dir(vim.fs.root(buf, { '.marksman.toml', '.git' }) or vim.fs.dirname(file))
  end,
}
