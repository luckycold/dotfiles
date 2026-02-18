return {
  'smnatale/workspace-diagnostics.nvim',
  event = 'LspAttach',
  cmd = {
    'WorkspaceDiagnostics',
    'WorkspaceDiagnosticsRefresh',
    'WorkspaceDiagnosticsStatus',
  },
  opts = {
    auto_trigger = true,
    lsp_progress = true,
    notify_progress = false,
    cache_ttl = 300,
    chunk_size = 10,
    chunk_delay = 1,
  },
}
