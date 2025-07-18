-- Function to get all bufferline buffer file paths
local function get_buffer_files()
  local files = {}
  local buffers = vim.api.nvim_list_bufs()

  for _, buf in ipairs(buffers) do
    -- Include all buffers that are listed (which includes bufferline tabs)
    if vim.api.nvim_buf_get_option(buf, "buflisted") then
      local name = vim.api.nvim_buf_get_name(buf)
      -- Check if buffer has a valid file path and exists on disk
      if name ~= "" and vim.fn.filereadable(name) == 1 then
        table.insert(files, vim.fn.shellescape(name))
      end
    end
  end

  return files
end

-- Function to create and execute the claude command
local function claude_with_buffers()
  local files = get_buffer_files()

  if #files == 0 then
    vim.notify("No file buffers found to pass to Claude", vim.log.levels.WARN)
    return
  end

  -- Create the claude command
  local claude_cmd = "claude "
    .. table.concat(files, " ")
    .. " use these files as context for our conversation, wait for my instructions"
    .. "\n"

  -- Get current working directory
  local cwd = vim.fn.getcwd()

  -- Spawn new pane with current working directory
  local spawn_cmd = string.format("wezterm cli spawn --cwd '%s'", cwd)
  local pane_id = vim.fn.system(spawn_cmd):gsub("%s+", "") -- Remove whitespace/newlines

  -- Set tab title
  local title_cmd = string.format("wezterm cli set-tab-title --pane-id='%s' 'claude'", pane_id)
  vim.fn.system(title_cmd)

  -- Send the claude command to the new pane
  local send_cmd = string.format("wezterm cli send-text --no-paste --pane-id='%s'", pane_id)
  vim.fn.system(send_cmd, claude_cmd)

  -- Notify user
  vim.notify(string.format("Started Claude Code with %d files in new WezTerm pane", #files))
end

-- Create the user command
vim.api.nvim_create_user_command("ClaudeBuffers", claude_with_buffers, {
  desc = "Open Claude Code with all current buffer files in a new WezTerm tab",
})

-- Create CaludeFiles UserCommand for open buffers only
vim.api.nvim_create_user_command("CaludeFiles", function(opts)
  local files = {}

  -- Get all listed buffers (all open files, not just active)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    -- Check if buffer is listed (shows up in :ls)
    if vim.api.nvim_buf_get_option(bufnr, "buflisted") then
      local bufname = vim.api.nvim_buf_get_name(bufnr)

      -- Only include actual files (not empty buffers or special buffers)
      if bufname ~= "" and vim.fn.filereadable(bufname) == 1 then
        -- Get relative path from cwd
        local relative_path = vim.fn.fnamemodify(bufname, ":.")
        table.insert(files, relative_path)
      end
    end
  end

  -- Sort files for consistent output
  table.sort(files)

  -- Format files with @<filepath> syntax
  local formatted_files = {}
  for _, file in ipairs(files) do
    table.insert(formatted_files, "@" .. file)
  end

  -- Join with ', ' and copy to clipboard
  local clipboard_content = table.concat(formatted_files, ", ")

  -- Copy to system clipboard
  vim.fn.setreg("+", clipboard_content)

  -- Also copy to unnamed register
  vim.fn.setreg('"', clipboard_content)

  -- Print confirmation message
  print("Copied " .. #files .. " open buffer file paths to clipboard in Claude Code format")

  -- Print the actual content for verification
  if #files > 0 then
    print("Content: " .. clipboard_content)
  else
    print("No file buffers found")
  end
end, {
  desc = "Copy open buffer file paths with @<filepath> syntax to clipboard for Claude Code",
})
