-- Notes in Obsidian vaults get links, completion and renames from obsidian.nvim instead
return {
  root_dir = function(buf, on_dir)
    local file = vim.api.nvim_buf_get_name(buf)
    for _, vault in ipairs(require 'config.vaults') do
      if vim.startswith(file, vault.path .. '/') then return end
    end
    on_dir(vim.fs.root(buf, { '.marksman.toml', '.git' }) or vim.fs.dirname(file))
  end,
}
