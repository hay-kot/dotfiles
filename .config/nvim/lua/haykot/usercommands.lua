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
