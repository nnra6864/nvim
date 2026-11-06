# nvim

Personal Neovim config.<br>
One file per plugin in [`lua/plugins`](lua/plugins), every keymap in [`lua/config/keymaps.lua`](lua/config/keymaps.lua).

## Features

- **Languages**: LSP, treesitter, formatting and debugging for C/C++, C#, Zig, Dart/Flutter, Python, Lua, Bash, fish, Markdown, Typst and YAML.<br>
  Servers that aren't installed are skipped.
- **Theme**: base16, live-reloaded from [Ricer](lua/config/colors.lua), with an oh-my-posh style statusline.
- **Notes**: replaces Obsidian inside any vault (a folder with `.obsidian`).<br>
  Links, backlinks, renames that fix links, timestamped notes, and TODO notes that carry open tasks over.
- **Git**: lazygit, VSCode-style diffs between any two commits, file and line history, blame, hunks in the gutter.
- **Files**: yazi instead of netrw.<br>
  Renaming or moving a file updates imports and note links.
- **Formatting** on save only for languages with one official style (Zig, Dart, fish) or projects with their own formatter config.<br>
  Otherwise `<leader>f`.
- **Indent**: one width per buffer, from editorconfig, else detected from the file, else per language.

## Requirements (Arch)

- Everything:
```sh
sudo pacman -S --needed neovim git base-devel tree-sitter-cli ripgrep fd yazi lazygit clang lua-language-server marksman ruff ty tinymist bash-language-server shellcheck yaml-language-server stylua shfmt jq websocat imagemagick ghostscript typst gdb python-debugpy
dotnet tool install --global roslyn-language-server --prerelease
mkdir -p ~/.local/share/netcoredbg ~/.local/bin && curl -L https://github.com/Samsung/netcoredbg/releases/latest/download/netcoredbg-linux-amd64.tar.gz | tar xz -C ~/.local/share/netcoredbg --strip-components=1 && ln -sf ~/.local/share/netcoredbg/netcoredbg ~/.local/bin/netcoredbg
```

Or only what you need:

- Core:
```sh
sudo pacman -S --needed neovim git base-devel tree-sitter-cli ripgrep fd yazi lazygit
```
- Language servers:
```sh
sudo pacman -S --needed clang lua-language-server marksman ruff ty tinymist bash-language-server shellcheck yaml-language-server
```
- C# language server:
```sh
dotnet tool install --global roslyn-language-server --prerelease
```
- Formatters (clang, ruff, fish and zig bring their own):
```sh
sudo pacman -S --needed stylua shfmt jq
```
- Typst preview:
```sh
sudo pacman -S --needed websocat
```
- Images in the editor (any format but PNG, PDFs, Typst math):
```sh
sudo pacman -S --needed imagemagick ghostscript typst
```
- Debuggers for C/C++/Zig and Python (Dart/Flutter use the Flutter SDK):
```sh
sudo pacman -S --needed gdb python-debugpy
```
- C# debugger, Samsung's official release:
```sh
mkdir -p ~/.local/share/netcoredbg ~/.local/bin && curl -L https://github.com/Samsung/netcoredbg/releases/latest/download/netcoredbg-linux-amd64.tar.gz | tar xz -C ~/.local/share/netcoredbg --strip-components=1 && ln -sf ~/.local/share/netcoredbg/netcoredbg ~/.local/bin/netcoredbg
```

Also:

- Zig: `zls` matching your zig version (e.g. via zvm).
- fish (optional, nothing else needs it): [fish-lsp](https://github.com/ndonfris/fish-lsp) adds completion, hover docs and diagnostics.<br>
  It's a Node.js tool that isn't in the official repos; highlighting and formatting work without it.
- Flutter: the SDK from fvm.
- Theme: Ricer writes it to `lua/theme.lua`, which isn't in the repo.<br>
  On a fresh clone, apply a theme in Ricer (or copy `lua/theme.lua` over); until then it's stock base16, without transparency.
- A [Nerd Font](https://www.nerdfonts.com).<br>
  Without one, set `vim.g.have_nerd_font = false` in `lua/config/options.lua`.
- Completion docs open with `Ctrl+Enter`, which most terminals don't pass through.<br>
  Ghostty needs this (it conflicts with many common binds, such as ones in lazygit):
```
keybind = ctrl+enter=unbind
```

## Keymaps

Leader is `Space`.<br>
Press a group key and wait for which-key to list the rest, or search them all with `<leader>sk`.<br>
Built-in Neovim keys are marked *(nvim)*.

| Editing | |
|---|---|
| `s` / `S` | Jump anywhere / select a syntax block (flash) |
| `gsa` `gsd` `gsr` | Add / delete / replace surrounding |
| `Alt+hjkl` | Move line or selection |
| `gcc`, `gc` | Comment *(nvim)* |
| `ii` `ai`, `[i` `]i` | Indent scope as a text object, jump to its edges |
| `]]` `[[` | Next / previous use of the symbol |
| `<leader>f` | Format |
| `za` `zR` `zM` | Toggle fold / open all / close all *(nvim)* |

| Completion (insert) | |
|---|---|
| `Ctrl+j` / `Ctrl+k` | Open menu, move down / up |
| `Enter`, `Ctrl+y` | Accept selection / accept ghost text |
| `Tab` `Shift+Tab` | Next / previous item or snippet field |
| `Ctrl+e`, `Ctrl+Enter` | Close / toggle docs |

| LSP | |
|---|---|
| `gd` `gD` | Definition / declaration |
| `grr` `gri` `grt` | References / implementations / type definition |
| `gO` `gW` | Symbols in file / workspace |
| `K`, `Ctrl+s` | Hover / signature help in insert *(nvim)* |
| `grn` `gra` | Rename / code action *(nvim)* |
| `]d` `[d`, `<leader>q` | Next / previous diagnostic *(nvim)*, diagnostics to loclist |

| Search `<leader>s` | |
|---|---|
| `<leader><leader>` `<leader>/` | Buffers / lines in buffer |
| `sf` `sg` `sw` `s.` | Files / grep / word under cursor / recent files |
| `sh` `sk` `sc` `sd` | Help / keymaps / commands / diagnostics |
| `st` `sn` `sr` `ss` | Themes (live preview) / config files / resume / all pickers |
| `sR` `sF` | Search and replace in project / file (grug-far) |

| Files and windows | |
|---|---|
| `<leader>ee` `ew` `eR` | Yazi at file / in cwd / resume |
| `<leader>er` `em` | Rename file / move it to a folder |
| `Ctrl+hjkl`, `Ctrl+w HJKL` | Focus window / move window *(nvim)* |
| `<leader>\|` `<leader>-` | Split vertically / horizontally |
| `<leader>z` `<leader>Z` | Zen mode / zoom window |
| `gC`, `<leader>n` | Jump to pinned context / notification history |

| Git `<leader>g` | |
|---|---|
| `gg` | Lazygit |
| `gd` `gc` | Changes and conflicts / diff commits (`Tab` marks two) |
| `gh` `gH` | History of file (or selected lines) / repo |
| `gb` `go` | Blame at cursor / inline diff overlay |
| `gB` `gY` | Open on remote / copy its URL |
| `]h` `[h`, `gh` `gH` | Next / previous hunk, apply / reset hunk (no leader) |

| Notes `<leader>o` | |
|---|---|
| `on` `ot` | New note / new TODO (takes over open tasks) |
| `od`, `]t` `[t` | Latest TODO, next / previous TODO |
| `oo` `os` | Find / search notes |
| `ob` `ol` `og` | Backlinks / links / tags |
| `op` `oN` `oT` | Paste image / new from template / insert template |
| `Enter` | In notes: follow link or toggle checkbox |

| Debug `<leader>d` | |
|---|---|
| `F5` `F10` `F11` `F12` | Start or continue / step over / into / out |
| `db` `dB` `dC` | Breakpoint / conditional breakpoint / run to cursor |
| `dw` `dh` `dv` | Watch / value under cursor / toggle debug view |
| `dl` `dt` | Rerun last / stop |

| Toggles `<leader>t` | |
|---|---|
| `tg` `td` `tf` | Ghost text / completion docs / format on save |
| `th` `tx` `tc` | Inlay hints / diagnostics / pinned context |
| `tw` `ts` `ti` `tS` | Wrap / spelling / indent guides / smooth scroll |
| `tm` `tp` | Markdown rendering / Typst preview |
| `<leader>i2` `i4` `i8` `it` | Indent width, tabs ↔ spaces (`ig` guess, `ir` retab) |

## Plugins

- [lazy.nvim](https://github.com/folke/lazy.nvim): plugin manager
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig), [lazydev.nvim](https://github.com/folke/lazydev.nvim): language server configs, Neovim Lua API
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), [nvim-treesitter-context](https://github.com/nvim-treesitter/nvim-treesitter-context): parsers, pinned context
- [blink.cmp](https://github.com/saghen/blink.cmp), [friendly-snippets](https://github.com/rafamadriz/friendly-snippets): completion, snippets
- [conform.nvim](https://github.com/stevearc/conform.nvim): formatting
- [mini.nvim](https://github.com/nvim-mini/mini.nvim): statusline, icons, pairs, surround, text objects, align, move, highlights, git and diff signs
- [snacks.nvim](https://github.com/folke/snacks.nvim): picker, notifications, indent guides, images, lazygit, zen, smooth scroll, toggles
- [which-key.nvim](https://github.com/folke/which-key.nvim): keymap hints
- [flash.nvim](https://github.com/folke/flash.nvim): jump motions
- [nvim-base16](https://github.com/RRethy/nvim-base16): colors
- [guess-indent.nvim](https://github.com/NMAC427/guess-indent.nvim): indent detection
- [keep-split-ratio.nvim](https://github.com/adlrwbr/keep-split-ratio.nvim): splits keep their ratio on resize
- [vim-abolish](https://github.com/tpope/vim-abolish): case-aware substitute and case conversion
- [yazi.nvim](https://github.com/mikavilpas/yazi.nvim): file manager
- [codediff.nvim](https://github.com/esmuellert/codediff.nvim): diffs, history, conflict resolution
- [grug-far.nvim](https://github.com/MagicDuck/grug-far.nvim): search and replace
- [nvim-dap](https://github.com/mfussenegger/nvim-dap), [nvim-dap-view](https://github.com/igorlfs/nvim-dap-view), [nvim-dap-python](https://github.com/mfussenegger/nvim-dap-python): debugging
- [flutter-tools.nvim](https://github.com/nvim-flutter/flutter-tools.nvim): Flutter and Dart
- [typst-preview.nvim](https://github.com/chomosuke/typst-preview.nvim): Typst live preview
- [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim): Markdown rendering
- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim): Obsidian vaults
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim): library used by flutter-tools and yazi.nvim

# ☦

```
   Ὤ
 Ὁ   Ν
Ι̅Ϲ̅ │ Χ̅Ϲ̅
───┼───
ΝΙ │ ΚΑ
   ☦
```

Εἰς δόξαν τοῦ Θεοῦ<br>
*To the glory of God*

Τῇ Ὑπεραγίᾳ Θεοτόκῳ δόξα<br>
*Glory to the Most Holy Theotokos*

Δόξα τῷ Θεῷ πάντων ἕνεκεν<br>
*Glory to God for all things*

ΑΜΗΝ

☦
