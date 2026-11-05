return {
  -- Runs the Dart language server itself, plus Flutter run/reload/devices commands
  'nvim-flutter/flutter-tools.nvim',
  ft = 'dart',
  dependencies = { 'nvim-lua/plenary.nvim' },
  opts = {
    fvm = true,
    lsp = { settings = { showTodos = true, completeFunctionCalls = true } },
  },
}
