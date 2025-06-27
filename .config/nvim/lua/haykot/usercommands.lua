-- Function to process the highlighted text
local function html_convert_para_to_list(tag)
  -- Get the start and end of the visual selection
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  -- Get the lines and columns of the visual selection
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  -- Table to store the processed lines
  local processed_lines = {}

  -- Add the opening <ul> tag
  table.insert(processed_lines, "<" .. tag .. ">")

  -- Process the selected text
  for line_num = start_line, end_line do
    local line = vim.fn.getline(line_num)
    -- Replace <p> with <li> and </p> with </li>
    line = line:gsub("<p>", "<li>")
    line = line:gsub("</p>", "</li>")
    table.insert(processed_lines, line)
  end

  -- Add the closing </ul> tag
  table.insert(processed_lines, "</" .. tag .. ">")

  -- Replace the selected lines with the processed lines
  -- but we need to ensure that we don't delete any lines because we
  -- have added text
  local num_lines = end_line - start_line + 1
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, processed_lines)
end

-- Create a custom command to trigger the function
vim.api.nvim_create_user_command("HtmlConvertParaToOl", function()
  html_convert_para_to_list("ol")
end, { range = true, desc = "Converts the selected paragraph tags into an ordered list" })
vim.api.nvim_create_user_command("HtmlConvertParaToUl", function()
  html_convert_para_to_list("ul")
end, { range = true, desc = "Converts the selected paragraph tags into an unordered list" })

vim.api.nvim_create_user_command("FinderReveal", function()
  local file_path = vim.fn.expand("%:p")
  local cmd = string.format("open -R %s", file_path)
  vim.fn.system(cmd)
end, { range = false, nargs = 0, desc = "Reveal the current file in Finder" })

vim.api.nvim_create_user_command("ThemeTokyonight", function()
  vim.cmd("colorscheme tokyonight")
end, { range = false, nargs = 0, desc = "Set the color scheme to tokyonight" })

vim.api.nvim_create_user_command("ThemeGruvboxMaterial", function()
  vim.cmd("colorscheme gruvbox-material")
end, { range = false, nargs = 0, desc = "Set the color scheme to gruvbox-material" })

vim.api.nvim_create_user_command("TrimTrailingWhitespace", function()
  local line_count = vim.api.nvim_buf_line_count(0)

  for i = 0, line_count - 1 do
    local line = vim.api.nvim_buf_get_lines(0, i, i + 1, false)[1]
    local trimmed_line = string.gsub(line, "%s+$", "")

    if line ~= trimmed_line then
      vim.api.nvim_buf_set_lines(0, i, i + 1, false, { trimmed_line })
    end
  end
end, { desc = "Trim trailing whitespace from all lines in the current file" })

-- Define a user command to toggle text wrapping
vim.api.nvim_create_user_command("ToggleWrap", function()
  vim.opt_local.wrap = not vim.opt_local.wrap:get()
  print("Wrap is now " .. (vim.opt_local.wrap:get() and "enabled" or "disabled"))
end, {})

-- Automatically aligns struct tags in a go struct
vim.api.nvim_create_user_command("AlignStructTags", function(opts)
  local start_line = opts.line1 - 1
  local end_line = opts.line2 - 1
  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line + 1, false)

  -- Find the maximum lengths for each column
  local max_field_len = 0
  local max_type_len = 0
  local max_json_len = 0

  for _, line in ipairs(lines) do
    -- Skip lines that don't contain struct fields
    if line:match("^%s*[A-Z]%w+%s+[%w%*]+%s+`") then
      local field, type_name = line:match("^%s*([A-Z]%w+)%s+([%w%*]+)%s+`")
      local json_tag = line:match('json:"([^"]+)"')

      if field and type_name then
        max_field_len = math.max(max_field_len, #field)
        max_type_len = math.max(max_type_len, #type_name)
        if json_tag then
          max_json_len = math.max(max_json_len, #json_tag)
        end
      end
    end
  end

  -- Format each line
  local new_lines = {}
  for _, line in ipairs(lines) do
    if line:match("^%s*[A-Z]%w+%s+[%w%*]+%s+`") then
      local field, type_name = line:match("^%s*([A-Z]%w+)%s+([%w%*]+)%s+`")
      local json_tag = line:match('json:"([^"]+)"')
      local validate_tag = line:match('validate:"([^"]+)"')

      if field and type_name then
        local new_line =
            string.format("\t%-" .. max_field_len .. "s %-" .. max_type_len .. 's `json:"%s"', field, type_name, json_tag)

        if validate_tag then
          -- Pad json tag to align validate tags
          new_line = string.format(
            "%-" .. (max_field_len + max_type_len + max_json_len + 11) .. 's validate:"%s"`',
            new_line,
            validate_tag
          )
        else
          new_line = new_line .. "`"
        end

        table.insert(new_lines, new_line)
      else
        table.insert(new_lines, line)
      end
    else
      table.insert(new_lines, line)
    end
  end

  -- Replace the lines in the buffer
  vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, new_lines)
end, { range = true, desc = "Align Go struct tags" })

-- Add this to your Neovim configuration (init.lua or a plugin file)

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

-- Optional: Create a keybinding for quick access
-- vim.keymap.set('n', '<leader>cc', claude_with_buffers, { desc = 'Claude Code with buffers' })
