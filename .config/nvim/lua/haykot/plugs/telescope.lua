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
        },
      })

      -- early return for windows (no fzf support atm)
      if require("haykot.lib.utils").windows() then
        return
      end

      -- To get fzf loaded and working with telescope, you need to call
      -- load_extension, somewhere after setup function:
      telescope.load_extension("fzf")
    end,
    keys = {
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
    },
  },
}
