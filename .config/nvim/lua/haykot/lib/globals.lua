M = {
  -- session_restored synchronizes the behavior of the auto-session plugin
  -- and the nvim-tree plugin. The auto-session plugin will restore the
  -- previous session on startup, but the nvim-tree plugin will open the
  -- file explorer on startup. This variable is used to prevent the
  -- nvim-tree plugin from opening the file explorer on startup if a
  -- session is restored.
  session_restored = false,
}

return M
