-- Debugging. Adapters, all from pacman or the SDKs themselves:
--   C, C++, Zig: gdb (built-in DAP mode)   Python: python-debugpy
--   C#: netcoredbg (AUR)                   Dart/Flutter: flutter-tools, via the Flutter SDK
-- Each language asks for what to run; Enter reuses the last answer.
local last = {}
local function ask(key, prompt, default)
  return function()
    return coroutine.create(function(co)
      vim.ui.input({ prompt = prompt, default = last[key] or default(), completion = 'file' }, function(input)
        if input and input ~= '' then last[key] = input end
        coroutine.resume(co, input and input ~= '' and input or require('dap').ABORT)
      end)
    end)
  end
end
local cwd = function() return vim.fn.getcwd() .. '/' end

return {
  {
    'mfussenegger/nvim-dap',
    lazy = true,
    dependencies = { 'igorlfs/nvim-dap-view', 'mfussenegger/nvim-dap-python' },
    config = function()
      local dap = require 'dap'

      dap.adapters.gdb = { type = 'executable', command = 'gdb', args = { '--interpreter=dap', '--eval-command', 'set print pretty on' } }
      local native = {
        { name = 'Launch', type = 'gdb', request = 'launch', cwd = '${workspaceFolder}', program = ask('native', 'Executable: ', cwd) },
        { name = 'Attach to process', type = 'gdb', request = 'attach', pid = require('dap.utils').pick_process },
      }
      dap.configurations.c, dap.configurations.cpp, dap.configurations.zig = native, native, native

      dap.adapters.coreclr = { type = 'executable', command = 'netcoredbg', args = { '--interpreter=vscode' } }
      dap.configurations.cs = {
        {
          name = 'Launch',
          type = 'coreclr',
          request = 'launch',
          program = ask('cs', 'DLL: ', function() return cwd() .. 'bin/Debug/' end),
        },
        { name = 'Attach to process', type = 'coreclr', request = 'attach', processId = require('dap.utils').pick_process },
      }

      -- Runs the project's venv (.venv / $VIRTUAL_ENV) when there is one; debugpy itself comes from the system
      require('dap-python').setup 'python3'

      -- Opens with a debug session and closes when it ends
      require('dap-view').setup { auto_toggle = true, virtual_text = { enabled = true } }

      for name, sign in pairs {
        DapBreakpoint = { '●', 'DiagnosticError' },
        DapBreakpointCondition = { '◆', 'DiagnosticWarn' },
        DapLogPoint = { '◆', 'DiagnosticInfo' },
        DapBreakpointRejected = { '○', 'Comment' },
        DapStopped = { '▶', 'DiagnosticOk' },
      } do
        vim.fn.sign_define(name, { text = sign[1], texthl = sign[2], linehl = name == 'DapStopped' and 'Visual' or nil })
      end
    end,
  },
  { 'igorlfs/nvim-dap-view', lazy = true },
  { 'mfussenegger/nvim-dap-python', lazy = true },
}
