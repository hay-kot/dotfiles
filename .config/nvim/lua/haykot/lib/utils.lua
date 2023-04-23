M = {}

--- file_exists checks if a file exists. Returns true if it does, false otherwise
-- @param name string: The name of the file
M.file_exists = function(name)
	local f = io.open(name, "r")
	return f ~= nil and io.close(f)
end

--- find_first searches for the first file in a list of files in a given directory
-- @param root string: The root directory to search in
-- @param files table: A table of strings containing the names of the files to search for
-- @return string: The path to the first file found
M.find_first = function(root, files)
	-- FIles is table of strings
	for _, file in pairs(files) do
		if M.file_exists(root .. "/" .. file) then
			return root .. "/" .. file
		end
	end
end

return M
