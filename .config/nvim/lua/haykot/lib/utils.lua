--- file_exists checks if a file exists. Returns true if it does, false otherwise
-- @param name string: The name of the file
local function file_exists(name)
  local f = io.open(name, "r")
  return f ~= nil and io.close(f)
end

local is_windows = nil

M = {
  file_exists = file_exists,
  --- find_first searches for the first file in a list of files in a given directory
  -- @param root string: The root directory to search in
  -- @param files table: A table of strings containing the names of the files to search for
  -- @return string: The path to the first file found
  find_first = function(root, files)
    -- FIles is table of strings
    for _, file in pairs(files) do
      if file_exists(root .. "/" .. file) then
        return root .. "/" .. file
      end
    end
  end,

  guard_module = function(modules)
    for _, module in pairs(modules) do
      if not pcall(require, module) then
        return false
      end
    end
    return true
  end,

  windows = function()
    if is_windows == nil then
      if vim.loop.os_uname().sysname == "Windows_NT" then
        is_windows = true
      else
        is_windows = false
      end
    end
    return is_windows
  end,
}

return M
