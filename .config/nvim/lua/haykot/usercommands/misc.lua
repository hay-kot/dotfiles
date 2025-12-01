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

-- Open markdown preview using glow in a floating Snacks terminal
vim.api.nvim_create_user_command("OpenPreview", function()
	local file_path = vim.fn.expand("%:p")
	if vim.bo.filetype ~= "markdown" then
		vim.notify("OpenPreview only works with markdown files", vim.log.levels.ERROR)
		return
	end

	local width = 100
	Snacks.terminal("glow -p -w " .. width .. " " .. vim.fn.shellescape(file_path), {
		interactive = true,
		win = {
			position = "float",
			height = 0.9,
			width = width + 4, -- extra padding for border
			border = "rounded",
		},
	})
end, { desc = "Open markdown preview with glow" })
