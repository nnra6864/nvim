# Config audit (2026-11-24)

A full pass over the config: every file read, startup and runtime tested headless, `lua-language-server --check` run over the repo, Neovim's logs read.

**Verdict:** in good shape.
- Startup is about 38 ms.
- There are no orphan plugins, and `lazy-lock.json` matches the spec.
- lua-language-server's check found only type nits.
- No errors at startup or when opening notes, the Bible or Lua files.

## Done

All committed, none pushed.

| Commit | What |
|---|---|
| `0ed4503` | Terminal maps stay out of lazygit's and yazi's way.<br>`<Esc><Esc>` is now only mapped in plain `:terminal` buffers, and `]]` `[[` only in normal mode. In terminal mode they made every `<Esc>`, `[` and `]` wait 300 ms for a second key, and lazygit switches tabs with `[` `]`. |
| `63c58cc` → `cb099f8` | Bible scope, see [Bible: where it works](#bible-where-it-works).<br>The first fix (vault notes only) was wrong and is replaced by `cb099f8`. |
| `41ae059` | README matches the current keys: flash on `<leader>j`, directories open the files picker, list continuation, autosave on focus loss.<br>`<leader>gc` no longer errors when confirmed on an empty list. |
| `7652b16` | `<leader>sF` works on files with spaces in their names.<br>grug-far splits its paths field on spaces, so `2026-11-23 00-21 TODO.md` was searched as three paths. |
| `de9ceff` | Removed the Bible's unused `ref.id()` and fixed `cursor_ref()`'s description. |
| `c142b8a` | `3o` on a list item typed `- foofoofoo` on one line (the count went to the `A` the mapping typed). The count is now ignored. |
| `555613b` | snacks.nvim and obsidian.nvim forks come from the GitHub mirrors (`nnra6864/…`), so a fresh install doesn't depend on git.nnstdios.com.<br>The installed clones' remotes were switched too, and a stale `perf/completion-cache` fetch refspec was removed from the obsidian.nvim clone. |
| `0638cfd` | lua_ls no longer refuses Lua files outside projects.<br>Home is a dotfiles git repo, so such files got `~` as their workspace. They now get their own folder. A Lua file sitting directly in `~` gets no lua_ls; there's no other way short of hacking around Neovim's `root_markers` fallback.<br>`linebreak` is on, so wrapped lines break between words. |
| `6fad4f1` | Enter and `o` don't continue lists and quotes inside Markdown code blocks.<br>The fence detection is now shared with mini.pairs' backtick handling (it was in `plugins/mini.lua` only). |

### Bible: where it works

- `data.find(path)` returns the Bible a file belongs to:
  - `vim.g.bible_root` when the file is inside it,
  - else a Bible found anywhere in the file's **vault** (`.obsidian`), else its **git repo**.
- In git repos, ignored folders don't count. The importer repo's `cache/Bible.old` is not a Bible.
- The home folder is never a project, so it is never scanned.
- Results are cached per path and per project. A project's Bible location is remembered in `stdpath('state')/bible.json`, as before.
- References, `K`/`gd`/`Enter`/`gy`/`grr` on them, and Bible completion are on only in files of a project that has a Bible. Elsewhere those keys are just the LSP's, as before.
- The Bible in use follows the file (or cwd) you're in. Leaving it keeps the last one, so `<leader>b…` pickers and `:Bible` still work from anywhere.
- `config/bible` no longer requires anything outside `config/bible`.
- Scan cost, once per project per session: a 6,600-folder Unity repo took 4 ms (git) and 25 ms (folder walk).

## Outside the repo (done)

- Removed `~/.local/share/nvim/mason/bin` from fish's universal `fish_user_paths`.
- Deleted `~/.local/state/nvim/{mason.log,lsp.log,nvim.log}` (about 10 MB, mostly harmless TUI warnings).

## TODO (for you)

- [ ] **Math rendering:** run `sudo pacman -S tectonic`; that's all that's left.
  - Notes' `$…$` / `$$…$$` is LaTeX (what Obsidian renders); snacks.image renders it with `tectonic` and the `latex` treesitter parser.
  - The parser is now in `lua/plugins/treesitter.lua`, and `tectonic` is in the README's install lines.
  - Typst math in `.typ` files goes through `typst`, which is installed. Typst *inside Markdown* isn't something Obsidian or any renderer understands.
- [ ] **Split the Bible into its own repo.** It's self-contained now. What's left:
  - Rename the `config.bible.*` requires to the plugin's namespace.
  - Decide whether the keymaps stay in `config/keymaps.lua` (the `<leader>b` maps and the `bible_keys` autocmd that wraps `<CR>`/`gd`/`K`/`gy`/`grr`) or move into the plugin with a `setup({ keys = … })`. `wrap_key` would go with them.
  - Point the blink provider (`plugins/blink.lua`, `module = 'config.bible.blink'`) at the new module.
  - Move the README's Bible section.
- [ ] **One Bible at a time.** The data caches (books, files, cross-references) hold one Bible and are reloaded when you switch to another one. Fine with one vault. Caches per Bible would be the cleaner shape if you ever have two.
- [ ] **Optional:** more leftovers from removed plugins in `~/.local/state/nvim`: `luasnip.log`, `neogit/`, `nio.log`, `mason-registry-update`, `netrw/`. Under 100 KB together. Also `~/.cache/nvim` is 169 MB and `~/.local/state/nvim/undo` is 84 MB.

## Checked and fine

- **Bible speed:** the first book opened in a session takes about 175 ms (parsing the 1.1 MB `xrefs.json`), later ones 10–60 ms. Cursor/verse lookups are cached per change.
- **Notes speed:** finding the last edited note scans the vault in 2.5 ms, and the vault lookups done per keystroke take about 15 µs each.
- **Indent order:** editorconfig, then guess-indent, then the language default, as `config/indent.lua` says.
- **Cursor restore:** restoring the cursor on reopen runs after filetype detection, so commit messages are skipped correctly.
- **`CodeDiff history %`:** CodeDiff expands `%` itself, so names with spaces work.
- **`bufnr(path)` in `files.lua` / `notes.lua`:** works for names with `[`, `,` and spaces (full path match).
- **Autosave:** never formats notes (Markdown isn't in conform's format-on-save list).
