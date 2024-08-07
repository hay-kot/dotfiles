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

local utils = require("haykot.lib.utils")

local telescope_make = {
  title = "Makefile",
  has_file = function(project_dir)
    local makefile = utils.find_first(project_dir, {
      "Makefile",
      "makefile",
      "GNUmakefile",
    })

    if makefile == nil then
      return nil
    end

    return makefile
  end,
  commands = function(makefile)
    -- Adapted From
    --    -> https://github.com/sopa0/telescope-makefile/blob/6e5b5767751dbf73ad4f126840dcf1abfc38e891/lua/telescope/_extensions/make.lua#L29-L33
    local cmd_str = "make"
      .. " -pRrq -C "
      .. vim.fn.shellescape(vim.fn.fnamemodify(makefile, ":h"))
      .. [[ 2>/dev/null |
              awk -F: '/^# Files/,/^# Finished Make data base/ {
                  if ($1 == "# Not a target") skip = 1;
                  if ($1 !~ "^[#.\t]") { if (!skip) {if ($1 !~ "^$")print $1}; skip=0 }
              }' 2>/dev/null | sort -u ]]

    local cmd = vim.fn.system(cmd_str)

    local lines = vim.split(cmd, "\n")

    -- filter out makefile literal
    local new_lines = {}
    for _, line in pairs(lines) do
      if line:lower() ~= "makefile" and line ~= "" then
        table.insert(new_lines, line)
      end
    end

    return new_lines
  end,
  preview = function(makefile, task_name)
    local lines = vim.fn.system("bat -p --color=never " .. makefile .. " | rg --after-context 100 " .. task_name .. ":")

    -- Split lines into a list
    lines = vim.split(lines, "\n")

    -- trim trailing lines after task definition
    local new_lines = {}
    for i, line in pairs(lines) do
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

    return { lines = new_lines, filetype = "make" }
  end,
  cmd = function(_, task_name)
    return "make " .. task_name
  end,
}

local telescope_taskfile = {
  title = "Taskfile",
  has_file = function(project_dir)
    local taskfile = utils.find_first(project_dir, {
      "Taskfile.yaml",
      "Taskfile.yml",
      "taskfile.yaml",
      "taskfile.yml",
    })

    if taskfile == nil then
      return nil
    end

    return taskfile
  end,
  commands = function(taskfile)
    -- Call task --list --json and get json output
    local task_list = vim.fn.system("task --list --json --taskfile " .. taskfile)

    -- Extract list of "tasks" from json
    task_list = vim.fn.json_decode(task_list)["tasks"]

    -- Create a list of task names
    local task_names = {}
    for _, task in pairs(task_list) do
      table.insert(task_names, task["name"])
    end

    return task_names
  end,
  cmd = function(taskfile, task_name)
    return "task " .. task_name .. ' --taskfile "' .. taskfile .. '"'
  end,
  preview = function(taskfile, task_name)
    -- Get all lines from taskfile where task name is entry[1]
    local task_lines =
      vim.fn.system("bat -p --color=never " .. taskfile .. " | rg --after-context 100 " .. task_name .. ":")

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

    return { lines = new_lines, filetype = "yaml" }
  end,
}

--- TaskFile function will search for a Taskfile in the current git project
--- and open a telescope picker with the list of tasks. If no Taskfile is
--- found, it will fallback to telescope-makefile.
--- @param mode string: mode of operation (wezterm | toggle), defaults to toggle
M.taskfile = function(mode)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")
  local previewers = require("telescope.previewers")

  mode = mode or "toggle"

  local project_dir = vim.fn.system("git rev-parse --show-toplevel")
  if project_dir == "" or project_dir == nil then
    print("Error: Could not determine project directory.")
    return
  end

  project_dir = project_dir:gsub("\n", "")

  local file_path = nil
  local commander = nil

  local taskfile_path = telescope_taskfile.has_file(project_dir)
  if taskfile_path ~= nil then
    file_path = taskfile_path
    commander = telescope_taskfile
  else
    local makefile_path = telescope_make.has_file(project_dir)

    if makefile_path == nil then
      print("Error: Could not find a Makefile or Taskfile.")
      return
    end

    file_path = makefile_path
    commander = telescope_make
  end

  local task_names = commander.commands(file_path)

  -- Call task in viewable window. If the mode is toggle it uses to TermExec
  -- command to open a terminal window and run the task. If the mode is
  -- wezterm, it uses the wezterm cli spawn command to run the task in a
  -- new wezterm tab. Note that the tab is terminated immidiately after the
  -- task is finished, as far as I've found there's no way around this.
  local function call_task(task_name)
    local command = commander.cmd(file_path, task_name)

    if mode == "toggle" then
      require("toggleterm") -- require toggleterm to ensure TermExec requires
      vim.cmd("TermExec cmd=" .. "'" .. command .. "'")
    elseif mode == "wezterm" then
      vim.fn.system("wezterm cli spawn --cwd='" .. project_dir .. "' -- " .. command)
    end
  end

  local opts = {}
  pickers
    .new(opts, {
      prompt_title = commander.title,
      finder = finders.new_table({ results = task_names }),
      sorter = conf.generic_sorter(opts),
      -- Previewer for taskfile shows only the valid task definition
      -- currently supports tasks up to 100 lines, which is likely enough
      -- for most use cases
      previewer = previewers.new_buffer_previewer({
        title = "Task",
        define_preview = function(self, entry, _)
          local args = commander.preview(file_path, entry[1]) or {}

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, args.lines)
          vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", args.filetype)
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

-- Telescope Config
return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.7", -- Fuzzy finder
    dependencies = {
      -- Nvim Utils
      { "nvim-lua/plenary.nvim" },

      -- Faster Fuzzy Searching
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
      },

      -- Undo Search Plugin
      { "debugloop/telescope-undo.nvim" },
    },
    config = function()
      -- close on escape
      local telescope = require("telescope")
      local actions = require("telescope.actions")
      local telescope_config = require("telescope.config")

      -- unpack depreciated in lua 5.2 but still works
      local vimgrep_args = { unpack(telescope_config.values.vimgrep_arguments) }

      -- Searches hidden directories and files by default
      -- with live_grep
      table.insert(vimgrep_args, "--hidden")
      table.insert(vimgrep_args, "--glob")
      table.insert(vimgrep_args, "!.git/*")

      telescope.setup({
        defaults = {
          sorting_strategy = "ascending",
          vimgrep_arguments = vimgrep_args,
          layout_config = {
            prompt_position = "top",
          },
          prompt_prefix = " ",
          mappings = {
            i = {
              ["<C-o>"] = function(prompt_bufnr)
                require("telescope.actions").select_default(prompt_bufnr)
                require("telescope.builtin").resume()
              end,
              ["<C-q>"] = function(prompt_bufnr)
                actions.smart_send_to_qflist(prompt_bufnr)
              end,
              ["<esc>"] = actions.close,
            },
          },
        },
        extensions = {
          fzf = {
            fuzzy = true, -- false will only do exact matching
            override_generic_sorter = true, -- override the generic sorter
            override_file_sorter = true, -- override the file sorter
            case_mode = "smart_case", -- or "ignore_case" or "respect_case"
            -- the default case_mode is "smart_case"
          },
          undo = {},
        },
      })

      -- early return for windows (no fzf support atm)
      if require("haykot.lib.utils").windows() then
        return
      end

      -- To get fzf loaded and working with telescope, you need to call
      -- load_extension, somewhere after setup function:
      telescope.load_extension("fzf")
      telescope.load_extension("undo")
    end,
    keys = {
      { "<leader>ff", M.project_files, desc = "find file" },
      {
        "<leader>fl",
        function()
          -- open last picker
          require("telescope.builtin").resume()
        end,
        desc = "resumes last telescope window",
      },
      {
        "<leader>fm",
        function()
          M.taskfile("toggle")
        end,
        desc = "run task/make in terminal",
      },
      {
        "<leader>fn",
        function()
          M.taskfile("wezterm")
        end,
        desc = "run task/make in new wezterm tab",
      },
      {
        "<leader>fg",
        function()
          require("telescope.builtin").live_grep()
        end,
        desc = "find in files",
      },
      {
        "<leader>fb",
        function()
          require("telescope.builtin").buffers()
        end,
        desc = "find buffer",
      },
      {
        "<leader>fib",
        function()
          require("telescope.builtin").live_grep({ search_dirs = { vim.fn.expand("%:p") } })
        end,
        desc = "find in buffer",
      },
      {
        "<leader>fr",
        function()
          require("telescope.builtin").lsp_references({})
        end,
        desc = "find lsp references",
      },
      {
        "<leader>fq",
        function()
          require("telescope.builtin").quickfix()
        end,
        desc = "find quickfix",
      },
      {
        "<leader>fj",
        function()
          require("telescope.builtin").jumplist()
        end,
        desc = "find jumplist",
      },
      {
        "<leader>fd",
        function()
          local actions = require("telescope.actions")
          local action_state = require("telescope.actions.state")

          local function open_nvim_tree(prompt_bufnr, map)
            map("i", "<c-o>", function()
              local selection = action_state.get_selected_entry()
              -- Open in finder
              vim.fn.system("open " .. selection.cwd .. "/" .. selection.value)
              actions.close(prompt_bufnr)
            end)

            actions.select_default:replace(function()
              local api = require("nvim-tree.api")

              actions.close(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              api.tree.open()
              api.tree.find_file(selection.cwd .. "/" .. selection.value)

              -- Add map to ctrl-O
            end)
            return true
          end

          require("telescope.builtin").find_files({
            find_command = { "fd", "--type", "directory", "--hidden", "--exclude", ".git/*" },
            attach_mappings = open_nvim_tree,
          })
        end,
        desc = "find directory",
      },
      {
        "<leader>fx",
        function()
          require("telescope.builtin").diagnostics()
        end,
        desc = "find trouble results",
      },
      {
        "<leader>fbc",
        function()
          require("telescope.builtin").git_bcommits()
        end,
        desc = "find current buffer commits",
      },
      {
        "<leader>fc",
        function()
          require("telescope.builtin").git_status()
        end,
        desc = "find changed files",
      },
      {
        "<leader>flc",
        function()
          print("TODO: find last command")
        end,
        desc = "find last command and execute it with TermExec",
      },
      {
        -- cmd + shift + p
        "<leader>P",
        function()
          require("telescope.builtin").autocommands()
        end,
        desc = "find autocommands",
      },
      {
        -- cmd + shift + p
        "<leader>fu",
        function()
          require("telescope").extensions.undo.undo()
        end,
        desc = "find undos",
      },
    },
  },
}
