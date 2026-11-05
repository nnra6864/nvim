return {
  -- Headings, tables, checkboxes, callouts and code blocks drawn in place.
  -- The line under the cursor and insert mode show the raw text.
  'MeanderingProgrammer/render-markdown.nvim',
  ft = 'markdown',
  opts = {
    -- Callout (> [!note]) and checkbox completion
    completions = { lsp = { enabled = true } },
    -- Needs utftex or latex2text; math is rendered as images by snacks.image instead
    latex = { enabled = false },
  },
}
