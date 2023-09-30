-- Pull in the wezterm API
local wezterm = require("wezterm")

local colors = {
	-- Red
	red = "#FB4934",
	tab_bg_inactive = "#1C1C1C",
	tab_bg_active = "#202325",
}

-- Equivalent to POSIX basename(3)
-- Given "/foo/bar" returns "bar"
-- Given "c:\\foo\\bar" returns "bar"
local function basename(s)
	return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

local ADMIN_ICON = utf8.char(0xf49c)

local CMD_ICON = utf8.char(0xe62a)
local PS_ICON = utf8.char(0xe70f)
local WSL_ICON = utf8.char(0xf83c)

local VIM_ICON = utf8.char(0xe62b)
local PAGER_ICON = utf8.char(0xf718)
local FUZZY_ICON = utf8.char(0xf0b0)
local HOURGLASS_ICON = utf8.char(0xf252)

local PYTHON_ICON = utf8.char(0xf820)
local NODE_ICON = utf8.char(0xe74e)
local DENO_ICON = utf8.char(0xe628)
local SHELL_ICON = utf8.char(0xe795)

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
	local background = colors.tab_bg_active
	local foreground = "#A89984"
	local dim_foreground = "#FABD2F"

	if tab.is_active then
		background = colors.tab_bg_active
		foreground = "#83A598"
	elseif hover then
		-- maybe set hover styles
	end

	local edge_foreground = background
	local process_name = tab.active_pane.foreground_process_name
	local pane_title = tab.active_pane.title
	local exec_name = basename(process_name):gsub("%.exe$", "")
	local title_with_icon

	if exec_name == "pwsh" then
		title_with_icon = PS_ICON .. " PS"
	elseif exec_name == "cmd" then
		title_with_icon = CMD_ICON .. " CMD"
	elseif exec_name == "wsl" or exec_name == "wslhost" then
		title_with_icon = WSL_ICON .. " WSL"
	elseif exec_name == "nvim" then
		-- Vim icon needs extra space!
		title_with_icon = VIM_ICON .. " " .. pane_title:gsub("^(%S+)%s+(%d+/%d+) %- nvim", " %2 %1")
	elseif exec_name == "bat" or exec_name == "less" or exec_name == "moar" then
		title_with_icon = PAGER_ICON .. " " .. exec_name:upper()
	elseif exec_name == "fzf" or exec_name == "hs" or exec_name == "peco" then
		title_with_icon = FUZZY_ICON .. " " .. exec_name:upper()
	elseif exec_name == "python" or exec_name == "hiss" then
		title_with_icon = PYTHON_ICON .. " " .. exec_name
	elseif exec_name == "node" then
		title_with_icon = NODE_ICON .. " " .. exec_name:upper()
	elseif exec_name == "deno" then
		title_with_icon = DENO_ICON .. " " .. exec_name:upper()
	elseif exec_name == "zsh" or exec_name == "bash" or exec_name == "fish" then
		title_with_icon = SHELL_ICON .. " " .. exec_name
	else
		title_with_icon = HOURGLASS_ICON .. " " .. exec_name
	end
	if pane_title:match("^Administrator: ") then
		title_with_icon = title_with_icon .. " " .. ADMIN_ICON
	end

	local id = SUB_IDX[tab.tab_index + 1]
	local title = " " .. wezterm.truncate_right(title_with_icon, max_width) .. " "

	return {
		{ Attribute = { Intensity = "Bold" } },
		{ Background = { Color = edge_background } },
		{ Foreground = { Color = edge_foreground } },
		{ Background = { Color = background } },
		{ Foreground = { Color = foreground } },
		{ Text = id },
		{ Text = title },
		{ Foreground = { Color = dim_foreground } },
		{ Background = { Color = edge_background } },
		{ Foreground = { Color = edge_foreground } },
		{ Attribute = { Intensity = "Normal" } },
	}
end)

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
	config = wezterm.config_builder()
end
-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme = "GruvboxDark"
config.line_height = 1.1
config.font = wezterm.font({
	family = "JetBrains Mono",
	weight = "Regular",
	harfbuzz_features = { "calt=0", "clig=0", "liga=0" }, -- Disable Ligatures
})
config.font_size = 16

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
