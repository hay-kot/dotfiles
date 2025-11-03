-- Pull in the wezterm API
local wezterm = require("wezterm")

-- Theme toggle: set to true for Tokyo Night, false for Gruvbox
local USE_TOKYO_NIGHT = true

-- Tokyo Night color scheme
local function get_tokyonight_colors()
  return {
    -- Main colors
    foreground = "#c0caf5",
    background = "#1a1b26",
    cursor_bg = "#c0caf5",
    cursor_border = "#c0caf5",
    cursor_fg = "#1a1b26",
    selection_bg = "#283457",
    selection_fg = "#c0caf5",
    split = "#7aa2f7",
    compose_cursor = "#ff9e64",
    scrollbar_thumb = "#292e42",

    -- ANSI colors
    ansi = {
      "#15161e", -- black
      "#f7768e", -- red
      "#9ece6a", -- green
      "#e0af68", -- yellow
      "#7aa2f7", -- blue
      "#bb9af7", -- magenta
      "#7dcfff", -- cyan
      "#a9b1d6", -- white
    },
    brights = {
      "#414868", -- bright black
      "#f7768e", -- bright red
      "#9ece6a", -- bright green
      "#e0af68", -- bright yellow
      "#7aa2f7", -- bright blue
      "#bb9af7", -- bright magenta
      "#7dcfff", -- bright cyan
      "#c0caf5", -- bright white
    },

    -- Tab bar colors
    tab_bar = {
      background = "#1a1b26",
      inactive_tab_edge = "#16161e",
      active_tab = {
        bg_color = "#7aa2f7",
        fg_color = "#16161e",
      },
      inactive_tab = {
        bg_color = "#292e42",
        fg_color = "#545c7e",
      },
      inactive_tab_hover = {
        bg_color = "#292e42",
        fg_color = "#7aa2f7",
      },
      new_tab = {
        bg_color = "#1a1b26",
        fg_color = "#7aa2f7",
      },
      new_tab_hover = {
        bg_color = "#1a1b26",
        fg_color = "#7aa2f7",
        intensity = "Bold",
      },
    },
  }
end

-- Get tab colors based on theme
local function get_tab_colors()
  if USE_TOKYO_NIGHT then
    return {
      red = "#f7768e",
      tab_bg_inactive = "#292e42",
      tab_bg_active = "#7aa2f7",
    }
  else
    -- Gruvbox colors
    return {
      red = "#FB4934",
      tab_bg_inactive = "#1C1C1C",
      tab_bg_active = "#202325",
    }
  end
end

local colors = get_tab_colors()

-- Equivalent to POSIX basename(3)
-- Given "/foo/bar" returns "bar"
-- Given "c:\\foo\\bar" returns "bar"
local function basename(s)
  return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

local SOLID_LEFT_ARROW = utf8.char(0xe0ba)
local SOLID_LEFT_MOST = utf8.char(0x2588)
local SOLID_RIGHT_ARROW = utf8.char(0xe0bc)

local PS_ICON = utf8.char(0xe70f)

local NVIM_ICON = utf8.char(0xe7c5) -- Neovim
local HOURGLASS_ICON = utf8.char(0xf252)

local SHELL_ICON = utf8.char(0xe795)
local TASK_RUNNING_ICON = utf8.char(0xf085)
local CPU_ICON = utf8.char(0xf4bc)
local RAM_ICON = utf8.char(0xf233)

local SUB_IDX = {
  "₁",
  "₂",
  "₃",
  "₄",
  "₅",
  "₆",
  "₇",
  "₈",
  "₉",
  "₁₀",
  "₁₁",
  "₁₂",
  "₁₃",
  "₁₄",
  "₁₅",
  "₁₆",
  "₁₇",
  "₁₈",
  "₁₉",
  "₂₀",
}

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local edge_background = colors.tab_bg_active
  local background = colors.tab_bg_inactive
  local foreground, dim_foreground

  if USE_TOKYO_NIGHT then
    local tokyo = get_tokyonight_colors()
    foreground = tokyo.ansi[8]
    dim_foreground = tokyo.split
    edge_background = tokyo.background
  else
    foreground = "#A89984"   -- Gruvbox foreground
    dim_foreground = "#FABD2F" -- Gruvbox yellow
  end

  if tab.is_active then
    background = colors.tab_bg_active
    if USE_TOKYO_NIGHT then
      foreground = "#16161e" -- Dark foreground for active tab (Tokyo Night)
    else
      foreground = "#859A99" -- Gruvbox active tab foreground
    end
  elseif hover then
    if USE_TOKYO_NIGHT then
      foreground = "#7aa2f7" -- Blue on hover (Tokyo Night)
    else
      -- Gruvbox hover styles can be added here if desired
    end
  end

  local edge_foreground = background
  local process_name = tab.active_pane.foreground_process_name
  local pane_title = tab.active_pane.title
  local assigned_title = tab.tab_title
  local exec_name = basename(process_name):gsub("%.exe$", "")
  local title_with_icon

  if assigned_title ~= "" then
    title_with_icon = SHELL_ICON .. " " .. assigned_title
  elseif exec_name == "pwsh" then
    title_with_icon = PS_ICON .. " PS"
  elseif exec_name == "task" then
    title_with_icon = TASK_RUNNING_ICON .. " Task"
  elseif exec_name == "nvim" then
    title_with_icon = NVIM_ICON .. " " .. pane_title:gsub("^(%S+)%s+(%d+/%d+) %- nvim", " %2 %1")
  elseif exec_name == "zsh" or exec_name == "bash" or exec_name == "fish" then
    title_with_icon = SHELL_ICON .. " " .. exec_name
  else
    title_with_icon = HOURGLASS_ICON .. " " .. exec_name
  end

  local left_arrow = SOLID_LEFT_ARROW
  if tab.tab_index == 0 then
    left_arrow = SOLID_LEFT_MOST
  end

  local id = SUB_IDX[tab.tab_index + 1]
  local title = " " .. wezterm.truncate_right(title_with_icon, max_width) .. " "

  return {
    { Attribute = { Intensity = "Bold" } },
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = left_arrow },
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = id },
    { Text = title },
    { Foreground = { Color = dim_foreground } },
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = SOLID_RIGHT_ARROW },
    { Attribute = { Intensity = "Normal" } },
  }
end)

-- Get CPU and RAM usage
local function get_system_usage()
  local success, stdout, stderr = wezterm.run_child_process({
    'sh', '-c',
    'top -l 1 | awk \'/CPU usage/ {print $3} /PhysMem/ {print $2}\' | sed \'s/%//\''
  })

  if success then
    local lines = {}
    for line in stdout:gmatch("[^\r\n]+") do
      table.insert(lines, line:match("^%s*(.-)%s*$") or "0")
    end
    local cpu_raw = lines[1] or "0"
    local cpu = string.format("%.1f", tonumber(cpu_raw) or 0)
    local ram = lines[2] or "0M"
    return cpu, ram
  end
  return "0.0", "0M"
end

-- Display CPU and RAM usage in right status area with caching
wezterm.on('update-status', function(window, pane)
  local now = os.time()
  local cache_duration = 5  -- Update every 5 seconds

  -- Initialize cache if needed
  if not wezterm.GLOBAL.system_cache then
    wezterm.GLOBAL.system_cache = {
      cpu = "0",
      ram = "0M",
      last_update = 0
    }
  end

  -- Update cache if stale
  if now - wezterm.GLOBAL.system_cache.last_update >= cache_duration then
    local cpu, ram = get_system_usage()
    wezterm.GLOBAL.system_cache.cpu = cpu
    wezterm.GLOBAL.system_cache.ram = ram
    wezterm.GLOBAL.system_cache.last_update = now
  end

  local stat_color
  if USE_TOKYO_NIGHT then
    stat_color = "#737aa2"  -- Tokyo Night subtle gray
  else
    stat_color = "#a89984"  -- Gruvbox muted foreground
  end

  window:set_right_status(wezterm.format({
    { Foreground = { Color = stat_color } },
    { Text = ' ' .. wezterm.GLOBAL.system_cache.cpu .. '% | ' .. wezterm.GLOBAL.system_cache.ram .. ' ' },
  }))
end)

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Apply colors based on theme selection
if USE_TOKYO_NIGHT then
  config.color_scheme = "tokyonight_night"
else
  config.color_scheme = "GruvboxDark"
end

-- Font configuration
config.line_height = 1.18
config.font = wezterm.font({
  family = "JetBrains Mono",
  weight = "Regular",
  harfbuzz_features = { "calt=0", "clig=0", "liga=0" }, -- Disable Ligatures
})
config.font_size = 16

-- Tab configuration
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false

config.window_frame = {
  font = wezterm.font("JetBrains Mono", { weight = "Bold" }),
  font_size = 14,
}

-- Set Padding to Zero
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

config.exit_behavior = "CloseOnCleanExit"
config.clean_exit_codes = {
  0,
  127, -- Default of `exit`
  130, -- Control-C
  201, -- Exit code on docker-compose stack when called from neovim terminal (don't know why)
}

-- and finally, return the configuration to wezterm
return config
