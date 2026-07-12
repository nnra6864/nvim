---@module 'lazy'
---@type LazySpec
return {
    "https://codeberg.org/ziglang/zig.vim",
    ft = { "zig", "zon" }, -- Lazy load it only when opening Zig files

    init = function()
        -- Don't show parse errors in a separate window
        vim.g.zig_fmt_parse_errors = 0
        -- Disable format-on-save from ziglang/zig.vim (using LSP instead)
        vim.g.zig_fmt_autosave = 0
    end,

    -- 3. Core setup, autocmds, and LSP configs belong in 'config'
    config = function()
        -- Formatting with ZLS matches `zig fmt`.
        vim.api.nvim_create_autocmd('BufWritePre', {
            pattern = { "*.zig", "*.zon" },
            callback = function(_)
                vim.lsp.buf.format()
            end
        })

        -- Code Actions on save: source.fixAll
        vim.api.nvim_create_autocmd('BufWritePre', {
            pattern = { "*.zig", "*.zon" },
            callback = function(_)
                vim.lsp.buf.code_action({
                    context = { only = { "source.fixAll" }, diagnostics = {} },
                    apply = true,
                })
            end
        })

        -- Code Actions on save: source.organizeImports
        vim.api.nvim_create_autocmd('BufWritePre', {
            pattern = { "*.zig", "*.zon" },
            callback = function(_)
                vim.lsp.buf.code_action({
                    context = { only = { "source.organizeImports" }, diagnostics = {} },
                    apply = true,
                })
            end
        })

        -- Set up ZLS using Neovim's built-in LSP client
        vim.lsp.config['zls'] = {
            -- Set to 'zls' if `zls` is in your PATH
            cmd = { 'zls' },
            filetypes = { 'zig' },
            root_markers = { 'build.zig' },
            -- Uncomment the following if ZLS is not in your PATH
            --settings = {
            --    zls = {
            --        zig_exe_path = '/path/to/zig_executable'
            --    }
            --},
        }

        -- Start/enable the language server
        vim.lsp.enable('zls')
    end
}
