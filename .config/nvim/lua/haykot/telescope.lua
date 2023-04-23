local M = {}

--- ProjectFiles function will search for a .git directory in the current
M.project_files = function()
  local ok = pcall(require("telescope.builtin").git_files, {
    show_untracked = true,
  })
  if not ok then
    require("telescope.builtin").find_files({
      find_command = { "rg", "--files", "--hidden", "--follow", "--glob", "!.git/*" },
    })
  end
end

--- Dotfiles function will search for a .dotfiles directory in the current
M.dotfiles = function()
  require("telescope.builtin").git_files({
    show_untracked = true,
    prompt_title = "~ dotfiles ~",
    cwd = "~/.dotfiles",
  })
end

--- TaskFile function will search for a Taskfile in the current git project
--- and open a telescope picker with the list of tasks. If no Taskfile is
--- found, it will fallback to telescope-makefile.
M.taskfile = function()
  local utils = require("haykot.lib.utils")
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")
  local previewers = require("telescope.previewers")

  local project_dir = vim.fn.system("git rev-parse --show-toplevel")
  if project_dir == "" or project_dir == nil then
    print("Error: Could not determine project directory.")
    return
  end

  local taskfile = utils.find_first(project_dir:gsub("\n", ""), {
    "Taskfile.yaml",
    "Taskfile.yml",
    "taskfile.yaml",
    "taskfile.yml",
  })

  if taskfile == nil then
    -- Fallback to telescope-makefile
    vim.cmd("Telescope make")
    return
  end

  -- Call task --list --json and get json output
  local task_list = vim.fn.system("task --list --json --taskfile " .. taskfile)

  -- Extract list of "tasks" from json
  task_list = vim.fn.json_decode(task_list)["tasks"]

  -- Create a list of task names
  local task_names = {}
  for _, task in pairs(task_list) do
    table.insert(task_names, task["name"])
  end

  local function call_task(task_name)
    -- Call task in viewable window
    vim.cmd("TermExec cmd=" .. "'task " .. task_name .. " --taskfile " .. taskfile .. "'")
  end

  local opts = {}
  pickers
      .new(opts, {
        prompt_title = "Taskfile",
        finder = finders.new_table({ results = task_names }),
        sorter = conf.generic_sorter(opts),
        -- Previewer for taskfile shows only the valid task definition
        -- currently supports tasks up to 100 lines, which is likely enough 
        -- for most use cases
        previewer = previewers.new_buffer_previewer({
          title = "Task",
          define_preview = function(self, entry, status)
            -- Get all lines from taskfile where task name is entry[1]
            local task_lines = vim.fn.system(
              "bat -p --color=never " .. taskfile .. " | rg --after-context 100 " .. entry[1] .. ":"
            )

            -- Split lines into a list
            task_lines = vim.split(task_lines, "\n")

            -- trim trailing lines after task definition
            local new_lines = {}
            for i, line in pairs(task_lines) do
              if line:match("^%s*$") then
                break
              end
              -- If line is a new task definition, break
              -- `  go:run:` two spaces is important
              if line:match("^%s%s%w+:") and i > 1 then
                break
              end

              table.insert(new_lines, line)
            end

            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, new_lines)
            vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "yaml")
          end,
        }),
        attach_mappings = function(prompt_bufnr, _)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local command = action_state.get_selected_entry()
            if not command then
              return
            end
            call_task(command[1])
          end)
          return true
        end,
      })
      :find()
end

return M
