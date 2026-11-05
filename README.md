# nvim

Personal Neovim config. Plugins via [lazy.nvim](https://github.com/folke/lazy.nvim), colors from base16 (live-reloaded from [Ricer](lua/config/colors.lua)).

## Requirements (Arch)

```sh
sudo pacman -S --needed neovim git base-devel tree-sitter-cli ripgrep fd
# Language servers, install the ones you need
sudo pacman -S --needed clang lua-language-server marksman ruff ty tinymist \
  bash-language-server shellcheck yaml-language-server
dotnet tool install --global roslyn-language-server --prerelease   # C#
paru -S fish-lsp                                                   # fish (AUR)
# Formatters (clang, ruff, fish and zig bring their own)
sudo pacman -S --needed stylua shfmt jq
```

- Zig: install `zls` matching your zig version (e.g. via zvm).
- Flutter: flutter-tools uses the SDK from fvm.
- A [Nerd Font](https://www.nerdfonts.com). Without one, set `vim.g.have_nerd_font = false` in `lua/config/options.lua`.

## Terminal

Completion opens with `Ctrl+Enter`, which most terminals don't pass through by default. In Ghostty:

```
# Conflicts with many common binds, such as ones in lazygit
keybind = ctrl+enter=unbind
```

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
