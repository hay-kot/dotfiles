local M = {}

M.projects = {
  ["recipinned"] = {
    keymaps = {
      -- Format: { mode, key, command, opts }
      { "n", "<leader>pq", ":!task gen:sqlc<CR>", { silent = true, desc = "Generate Sqlc" } },
    },
    commands = {},
    setup = function() end,
  },
}

-- Function to apply project configuration
function M.apply_project_config()
  local cwd = vim.fn.getcwd()

  -- Try to find a matching project
  for pattern, config in pairs(M.projects) do
    -- Check if current directory matches the regex pattern
    if cwd:match(pattern) then
      -- Apply keymaps
      if config.keymaps then
        for _, keymap in ipairs(config.keymaps) do
          local mode, key, command, opts = unpack(keymap)
          vim.keymap.set(mode, key, command, opts)
        end
      end

      -- Create commands
      if config.commands then
        for _, cmd in ipairs(config.commands) do
          local name, command, opts = unpack(cmd)
          vim.api.nvim_create_user_command(name, command, opts)
        end
      end

      -- Run setup function if it exists
      if config.setup and type(config.setup) == "function" then
        config.setup()
      end

      -- Print confirmation
      vim.notify("Loaded project config for pattern: " .. pattern, vim.log.levels.INFO)

      -- Found a matching project, no need to continue
      return true
    end
  end

  -- No matching project found
  return false
end

-- Setup function that should be called from init.lua
function M.setup()
  -- Auto-detect project when Neovim starts
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      M.apply_project_config()
    end,
  })

  -- Command to manually reload project config
  vim.api.nvim_create_user_command("ReloadProjectConfig", function()
    M.apply_project_config()
  end, {})
end

return M
