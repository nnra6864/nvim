return {
  -- Live preview in the browser, scrolling along with the cursor
  'chomosuke/typst-preview.nvim',
  version = '1.*',
  ft = 'typst',
  opts = {
    -- System binaries from pacman instead of the plugin downloading its own
    dependencies_bin = { tinymist = 'tinymist', websocat = 'websocat' },
  },
}
