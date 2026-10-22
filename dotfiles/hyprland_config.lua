hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("NIXOS_OZONE_WL", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

local mod = "ALT"

local function mod_key(key)
	return mod .. " + " .. key
end

hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "auto",
	scale = 1,
})

hl.config({
	general = {
		gaps_in = 8,
		gaps_out = 8,
		border_size = 3,
		col = {
			active_border = "rgba(89b4faff)",
			inactive_border = "rgba(45475aff)",
		},
		resize_on_border = false,
		allow_tearing = false,
		layout = "master",
	},
	decoration = {
		rounding = 5,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = true,
			range = 20,
			render_power = 3,
			offset = { 0, 4 },
			color = 0x77000000,
		},
		blur = {
			enabled = true,
			size = 8,
			passes = 3,
		},
	},
	animations = {
		enabled = true,
	},
	master = {
		mfact = 0.6,
		new_status = "slave",
		orientation = "left",
		allow_small_split = false,
	},
	group = {
		col = {
			border_active = "rgba(00000000)",
			border_inactive = "rgba(00000000)",
			border_locked_active = "rgba(00000000)",
			border_locked_inactive = "rgba(00000000)",
		},
		groupbar = {
			enabled = true,
			blur = false,
			gradients = true,
			gradient_round_only_edges = false,
			gradient_rounding = 0,
			gaps_in = 5,
			gaps_out = 0,
			keep_upper_gap = false,
			font_size = 16,
			font_weight_active = "ultraheavy",
			font_weight_inactive = "normal",
			height = 30,
			indicator_gap = 0,
			indicator_height = 4,
			render_titles = true,
			rounding = 0,
			text_color = "rgba(f9e2afff)",
			text_color_inactive = "rgba(7f849cff)",
			text_color_locked_active = "rgba(f38ba8ff)",
			text_color_locked_inactive = "rgba(6c7086ff)",
			text_padding = 8,
			col = {
				active = "rgba(1e66f5ff)",
				inactive = "rgba(313244ff)",
				locked_active = "rgba(f38ba8ff)",
				locked_inactive = "rgba(45475aff)",
			},
		},
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
})

hl.window_rule({
	name = "kitty-tiled",
	match = { class = "^kitty$" },
	float = false,
	tile = true,
	fullscreen_state = "0 0",
	suppress_event = "fullscreen maximize fullscreenoutput",
})

hl.window_rule({
	name = "brave-default-floating",
	match = { class = "^brave-.*-Default$" },
	float = true,
})

local function start_session_services()
	hl.exec_cmd("ironbar")
	hl.exec_cmd(
		"wallpaper=$(find \"$(dirname \"$(readlink -f \"$HOME/.config/hypr/hyprland.lua\")\")/../static_file/wallpaper\" -type f -name '*.mp4' | shuf -n 1); [ -n \"$wallpaper\" ] && mpvpaper -o 'no-audio loop panscan=1' '*' \"$wallpaper\""
	)
	hl.exec_cmd(
		"systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE; systemctl --user restart fcitx5"
	)
	hl.exec_cmd(
		"swayidle -w timeout 600 'swaylock -f' timeout 660 \"hyprctl dispatch 'hl.dsp.dpms({ action = \\\"disable\\\" })'\" resume \"hyprctl dispatch 'hl.dsp.dpms({ action = \\\"enable\\\" })'\" before-sleep 'swaylock -f'"
	)
	hl.exec_cmd(
		"dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE; systemctl --user restart xdg-desktop-portal"
	)
end

hl.on("hyprland.start", start_session_services)

local function switch_focus_between_floating_and_tiling()
	local active = hl.get_active_window()
	if active == nil then
		return
	end

	local target_floating = not active.floating
	for _, window in ipairs(hl.get_windows()) do
		if
			window.workspace ~= nil
			and active.workspace ~= nil
			and window.workspace.id == active.workspace.id
			and window.floating == target_floating
		then
			hl.dispatch(hl.dsp.focus({ window = window }))
			return
		end
	end
end

local master_presets = { 0.33333, 0.4, 0.5, 0.66667 }
local master_preset_index = 2

local function switch_master_preset()
	master_preset_index = master_preset_index % #master_presets + 1
	hl.dispatch(hl.dsp.layout("mfact exact " .. master_presets[master_preset_index]))
end

local function reset_master_layout()
	hl.dispatch(hl.dsp.layout("mfact exact 0.4"))
end

local function resize_active_height(factor)
	local active = hl.get_active_window()
	if active == nil or active.size == nil or active.size.y == nil then
		return
	end

	local amount = math.max(1, math.floor(active.size.y * math.abs(factor)))
	if factor < 0 then
		amount = -amount
	end

	hl.dispatch(hl.dsp.window.resize({ x = 0, y = amount, relative = true, window = active }))
end

local function consume_or_expel(direction)
	local active = hl.get_active_window()
	if active ~= nil and active.group ~= nil then
		hl.dispatch(hl.dsp.window.move({ out_of_group = direction }))
	else
		hl.dispatch(hl.dsp.window.move({ into_or_create_group = direction }))
	end
end

hl.bind(
	mod_key("SHIFT + SLASH"),
	hl.dsp.exec_cmd("notify-send 'Hyprland快捷键' 'hyprland使用lua暂不支持查看快捷菜单列表。'"),
	{ description = "keybind list unavailable | Hyprland 使用 Lua，暂不支持查看快捷键列表" }
)

hl.bind(mod_key("RETURN"), hl.dsp.exec_cmd("ghostty"), { description = "terminal (ghostty) | 终端 (ghostty)" })
hl.bind(
	mod_key("SHIFT + RETURN"),
	hl.dsp.exec_cmd("ghostty-random-bg"),
	{ description = "random background terminal (ghostty) | 随机背景终端 (ghostty)" }
)
hl.bind(
	mod_key("SHIFT + E"),
	hl.dsp.exec_cmd("thunar"),
	{ description = "file manager (thunar) | 文件管理器 (thunar)" }
)
hl.bind(mod_key("SHIFT + B"), hl.dsp.exec_cmd("brave"), { description = "web browser (brave) | 浏览器 (brave)" })
hl.bind(
	mod_key("CTRL + SHIFT + RETURN"),
	hl.dsp.exec_cmd("kitty"),
	{ description = "terminal (kitty) | 终端 (kitty)" }
)
hl.bind(mod_key("SHIFT + R"), hl.dsp.exec_cmd("rofi -show drun"), { description = "app launcher | 应用启动器" })
hl.bind(
	mod_key("CTRL + SHIFT + R"),
	hl.dsp.exec_cmd("systemctl --user restart fcitx5"),
	{ description = "restart input method (fcitx5) | 重启输入法 (fcitx5)" }
)
hl.bind(mod_key("SHIFT + Q"), hl.dsp.window.close(), { description = "close window | 关闭窗口" })
hl.bind(mod_key("CTRL + SHIFT + E"), hl.dsp.exit(), { description = "quit Hyprland | 退出 Hyprland" })
hl.bind(
	mod_key("mouse:272"),
	hl.dsp.window.drag(),
	{ mouse = true, description = "move window with Alt+left mouse button | 使用 Alt+鼠标左键移动窗口" }
)
hl.bind(mod_key("mouse:273"), hl.dsp.window.resize(), {
	mouse = true,
	description = "resize window with Alt+right mouse button | 使用 Alt+鼠标右键调整窗口大小",
})

hl.bind(
	mod_key("SHIFT + 1"),
	hl.dsp.focus({ workspace = 1 }),
	{ description = "focus workspace 1 | 聚焦工作区 1" }
)
hl.bind(
	mod_key("SHIFT + 2"),
	hl.dsp.focus({ workspace = 2 }),
	{ description = "focus workspace 2 | 聚焦工作区 2" }
)
hl.bind(
	mod_key("SHIFT + 3"),
	hl.dsp.focus({ workspace = 3 }),
	{ description = "focus workspace 3 | 聚焦工作区 3" }
)
hl.bind(
	mod_key("SHIFT + 4"),
	hl.dsp.focus({ workspace = 4 }),
	{ description = "focus workspace 4 | 聚焦工作区 4" }
)
hl.bind(
	mod_key("SHIFT + 5"),
	hl.dsp.focus({ workspace = 5 }),
	{ description = "focus workspace 5 | 聚焦工作区 5" }
)
hl.bind(
	mod_key("SHIFT + 6"),
	hl.dsp.focus({ workspace = 6 }),
	{ description = "focus workspace 6 | 聚焦工作区 6" }
)
hl.bind(
	mod_key("SHIFT + 7"),
	hl.dsp.focus({ workspace = 7 }),
	{ description = "focus workspace 7 | 聚焦工作区 7" }
)
hl.bind(
	mod_key("SHIFT + 8"),
	hl.dsp.focus({ workspace = 8 }),
	{ description = "focus workspace 8 | 聚焦工作区 8" }
)
hl.bind(
	mod_key("SHIFT + 9"),
	hl.dsp.focus({ workspace = 9 }),
	{ description = "focus workspace 9 | 聚焦工作区 9" }
)
hl.bind(
	mod_key("SHIFT + S"),
	hl.dsp.workspace.toggle_special("magic"),
	{ description = "toggle special workspace | 切换特殊工作区" }
)
hl.bind(
	mod_key("CTRL + SHIFT + S"),
	hl.dsp.window.move({ workspace = "special:magic" }),
	{ description = "move window to special workspace | 移动窗口到特殊工作区" }
)
hl.bind(
	mod_key("CTRL + SHIFT + 1"),
	hl.dsp.window.move({ workspace = 1 }),
	{ description = "move window to workspace 1 | 移动窗口到工作区 1" }
)
hl.bind(
	mod_key("CTRL + SHIFT + 2"),
	hl.dsp.window.move({ workspace = 2 }),
	{ description = "move window to workspace 2 | 移动窗口到工作区 2" }
)
hl.bind(
	mod_key("CTRL + SHIFT + 3"),
	hl.dsp.window.move({ workspace = 3 }),
	{ description = "move window to workspace 3 | 移动窗口到工作区 3" }
)
hl.bind(
	mod_key("CTRL + SHIFT + 4"),
	hl.dsp.window.move({ workspace = 4 }),
	{ description = "move window to workspace 4 | 移动窗口到工作区 4" }
)
hl.bind(
	mod_key("CTRL + SHIFT + 5"),
	hl.dsp.window.move({ workspace = 5 }),
	{ description = "move window to workspace 5 | 移动窗口到工作区 5" }
)
hl.bind(
	mod_key("CTRL + SHIFT + 6"),
	hl.dsp.window.move({ workspace = 6 }),
	{ description = "move window to workspace 6 | 移动窗口到工作区 6" }
)
hl.bind(
	mod_key("CTRL + SHIFT + 7"),
	hl.dsp.window.move({ workspace = 7 }),
	{ description = "move window to workspace 7 | 移动窗口到工作区 7" }
)
hl.bind(
	mod_key("CTRL + SHIFT + 8"),
	hl.dsp.window.move({ workspace = 8 }),
	{ description = "move window to workspace 8 | 移动窗口到工作区 8" }
)
hl.bind(
	mod_key("CTRL + SHIFT + 9"),
	hl.dsp.window.move({ workspace = 9 }),
	{ description = "move window to workspace 9 | 移动窗口到工作区 9" }
)
hl.bind(mod_key("SHIFT + A"), hl.dsp.exec_cmd("rofi -show window"), { description = "window switcher | 窗口切换" })

hl.bind(
	mod_key("SHIFT + LEFT"),
	hl.dsp.focus({ direction = "left" }),
	{ description = "focus column left | 聚焦左列" }
)
hl.bind(
	mod_key("SHIFT + RIGHT"),
	hl.dsp.focus({ direction = "right" }),
	{ description = "focus column right | 聚焦右列" }
)
hl.bind(
	mod_key("SHIFT + UP"),
	hl.dsp.focus({ direction = "up" }),
	{ description = "focus window up | 聚焦上方窗口" }
)
hl.bind(
	mod_key("SHIFT + DOWN"),
	hl.dsp.focus({ direction = "down" }),
	{ description = "focus window down | 聚焦下方窗口" }
)
hl.bind(
	mod_key("CTRL + SHIFT + LEFT"),
	hl.dsp.window.move({ direction = "left", group_aware = true }),
	{ description = "move column left | 移动列到左侧" }
)
hl.bind(
	mod_key("CTRL + SHIFT + RIGHT"),
	hl.dsp.window.move({ direction = "right", group_aware = true }),
	{ description = "move column right | 移动列到右侧" }
)
hl.bind(
	mod_key("CTRL + SHIFT + UP"),
	hl.dsp.window.move({ direction = "up" }),
	{ description = "move window up | 移动窗口向上" }
)
hl.bind(
	mod_key("CTRL + SHIFT + DOWN"),
	hl.dsp.window.move({ direction = "down" }),
	{ description = "move window down | 移动窗口向下" }
)

hl.bind(
	mod_key("CTRL + SHIFT + F"),
	hl.dsp.window.fullscreen({ mode = "fullscreen" }),
	{ description = "fullscreen window | 全屏窗口" }
)
hl.bind(
	mod_key("CTRL + SHIFT + M"),
	hl.dsp.layout("swapwithmaster master"),
	{ description = "swap active window with master | 交换活动窗口与主窗口" }
)
hl.bind(
	mod_key("SHIFT + M"),
	hl.dsp.window.fullscreen({ mode = "maximized" }),
	{ description = "maximize window to edges | 最大化窗口到边缘" }
)
hl.bind(
	mod_key("SHIFT + V"),
	hl.dsp.exec_cmd("dms ipc call clipboard toggle"),
	{ description = "toggle clipboard | 切换剪切板" }
)
hl.bind(
	mod_key("CTRL + SHIFT + V"),
	switch_focus_between_floating_and_tiling,
	{ description = "switch focus (floating/tiling) | 切换焦点 (浮动/平铺)" }
)
hl.bind(
	mod_key("SHIFT + W"),
	hl.dsp.group.toggle(),
	{ description = "toggle column tabbed display | 切换列标签显示" }
)
hl.bind(
	mod_key("SHIFT + G"),
	hl.dsp.group.toggle(),
	{ description = "toggle window group | 切换窗口分组" }
)
hl.bind(
	mod_key("CTRL + SHIFT + G"),
	hl.dsp.window.move({ out_of_group = true }),
	{ description = "remove window from group | 移出窗口分组" }
)
hl.bind(
	mod_key("CTRL + SHIFT + W"),
	switch_master_preset,
	{ description = "switch preset column width | 切换预设列宽" }
)
hl.bind(mod_key("SHIFT + H"), reset_master_layout, { description = "reset window height | 重置窗口高度" })
hl.bind(mod_key("MINUS"), hl.dsp.layout("mfact -0.1"), { description = "column width -10% | 列宽 -10%" })
hl.bind(mod_key("EQUAL"), hl.dsp.layout("mfact +0.1"), { description = "column width +10% | 列宽 +10%" })
hl.bind(mod_key("SHIFT + MINUS"), function()
	resize_active_height(-0.1)
end, { description = "window height -10% | 窗口高度 -10%" })
hl.bind(mod_key("SHIFT + EQUAL"), function()
	resize_active_height(0.1)
end, { description = "window height +10% | 窗口高度 +10%" })
hl.bind(
	mod_key("COMMA"),
	hl.dsp.window.move({ into_or_create_group = "right" }),
	{ description = "consume window into column | 并入列" }
)
hl.bind(
	mod_key("PERIOD"),
	hl.dsp.window.move({ out_of_group = true }),
	{ description = "expel window from column | 移出列" }
)
hl.bind(mod_key("BRACKETLEFT"), function()
	consume_or_expel("left")
end, { description = "consume/expel window (left) | 并入/移出列 (左)" })
hl.bind(mod_key("BRACKETRIGHT"), function()
	consume_or_expel("right")
end, { description = "consume/expel window (right) | 并入/移出列 (右)" })
-- hl.bind(mod_key("SHIFT + C"), hl.dsp.layout("orientationcenter"), { description = "center column | 居中列" })
-- hl.bind(
-- 	mod_key("CTRL + SHIFT + C"),
-- 	hl.dsp.layout("orientationleft"),
-- 	{ description = "set column orientation left | 设置列方向为左" }
-- )

hl.bind(
	mod_key("SHIFT + O"),
	hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"),
	{ description = "toggle overview | 切换概览" }
)
hl.bind(
	mod_key("SHIFT + P"),
	hl.dsp.exec_cmd("flameshot gui"),
	{ description = "screenshot (flameshot) | 截图 (flameshot)" }
)
hl.bind(
	mod_key("CTRL + SHIFT + P"),
	hl.dsp.exec_cmd(
		'sh -c \'mkdir -p "$HOME/Pictures/Screenshots"; grimblast --notify copysave area "$HOME/Pictures/Screenshots/Screenshot from $(date +"+%Y-%m-%d %H-%M-%S").png"\''
	),
	{ description = "select area screenshot, copy and notify | 自由选取截图、复制到剪贴板并通知" }
)
