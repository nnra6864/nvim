return {
  -- lspconfig's default prefers a project's node_modules/.bin copy, which would run
  -- whatever a cloned repo ships just by opening a yaml file. Use the system one only.
  cmd = { 'yaml-language-server', '--stdio' },
}
