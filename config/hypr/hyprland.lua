-- hyprland.lua: day-one Hyprland config for the fresh install. A terminal, a
-- browser, workspaces, and the laptop keys, so the real config can be written
-- on the machine itself. Copy this directory to ~/.config/hypr, or point
-- dotfiles' config/hypr at your own version. Nothing here is meant to last.
--
-- Start from the TTY:   uwsm start hyprland.desktop
-- uwsm runs Hyprland as a user unit and activates graphical-session.target once
-- `uwsm finalize` runs (below), which starts every enabled unit wanted by it:
--   systemctl --user enable hyprpolkitagent hypridle hyprsunset hyprpaper batsignal
-- quickshell ships no unit of its own; ~/.config/systemd/user/quickshell.service
-- is machine-local, since mise's [dotfiles] would symlink a tracked config/systemd
-- and systemctl would then write its .wants links back into the repo.
-- Exit with SUPER+SHIFT+Escape (`uwsm stop`), not by killing Hyprland.
--
-- Reference for the hl.* API: Omarchy's default/hypr/*.lua
-- (github.com/omacom/omarchy, branch quattro) is the largest example of
-- hl.config / hl.bind / hl.dsp.* in the wild. Two things worth knowing:
--   * `hyprctl dispatch` takes Lua too:  hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'
--     The old `hyprctl dispatch dpms off` form is a parse error on 0.56.
--   * Launch apps through `uwsm-app -- <cmd>` so they get their own scope and
--     outlive a compositor restart cleanly.

-- Files next to this one (media-keys.lua) load relative to it, so the config
-- can be verified from a checkout: Hyprland --verify-config -c path/to/hyprland.lua
local hypr = (debug and debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$"))
  or (os.getenv("HOME") .. "/.config/hypr")

-- 2880x1800 OLED at 1.6 = 1800x1125 logical, GDK_SCALE 2 (what the Omarchy config used).
hl.env("GDK_SCALE", "2")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.6 })

hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
  input = {
    kb_layout = "us",
    kb_options = "ctrl:nocaps,shift:both_capslock",
    repeat_rate = 40,
    repeat_delay = 250,
    numlock_by_default = true,
    sensitivity = 0.75,
    accel_profile = "flat",
    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = true,
      scroll_factor = 0.4,
      disable_while_typing = true,
      drag_3fg = 1,
    },
  },
  -- resize_on_border lets a border or gap be dragged directly to resize, with no
  -- modifier, which is what most people mean by resizing "like a normal window".
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 2,
    layout = "dwindle",
    resize_on_border = true,
  },
  decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } },
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true },
})

hl.on("hyprland.start", function()
  -- Hand WAYLAND_DISPLAY & co. to the user manager and D-Bus; uwsm then
  -- activates graphical-session.target. Hyprland does not do this by itself.
  hl.exec_cmd("uwsm finalize")
  hl.exec_cmd("uwsm-app -- udiskie --automount --no-notify --no-tray")
end)

local function app(command) return hl.dsp.exec_cmd("uwsm-app -- " .. command) end

-- Launcher. wofi is a menu rather than an app, so it is deliberately not run
-- through uwsm-app: anything launched from it would inherit wofi's transient
-- scope and outlive it there under a misleading name.
-- pkill-first makes the key a toggle; without it a second press stacks a
-- second instance on top of the first.
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("sh -c 'pkill wofi || wofi --show drun'"))

hl.bind("SUPER + RETURN", app("ghostty"))
hl.bind("SUPER + SHIFT + RETURN", app("chromium"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("loginctl lock-session")) -- hypridle runs hyprlock
hl.bind("SUPER + SHIFT + ESCAPE", hl.dsp.exec_cmd("uwsm stop"))

-- Focus and move, aerospace's alt-hjkl / alt-shift-hjkl. `move` rather than
-- `swap`: aerospace's `move left` relocates the window in the tree, which is
-- what move does; swap trades places with whatever is already there.
for key, dir in pairs({ H = "l", J = "d", K = "u", L = "r" }) do
  hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = dir }))
  hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
end

-- Window management, from aerospace's [mode.main.binding].
--
-- mode is "fullscreen" or "maximized" ("maximize" is rejected). maximized fills
-- the workspace but keeps gaps and the bar; fullscreen covers everything.
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
-- Not SUPER+SHIFT+M: that is "move to workspace M" in workspaces.lua.
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized" }))

-- aerospace put float toggling behind service mode (alt-shift-semicolon then f).
-- A direct bind is less ceremony for the one service-mode command that has a
-- real dwindle equivalent.
hl.bind("SUPER + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))

-- alt-slash flipped tiles between horizontal and vertical; togglesplit is the
-- dwindle equivalent. alt-comma was `layout accordion`, which dwindle has no
-- form of: a tabbed group is the nearest thing, one window visible at a time.
hl.bind("SUPER + SLASH", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + COMMA", hl.dsp.group.toggle())

-- alt-shift-minus / alt-shift-equal, resize smart -+100.
hl.bind("SUPER + SHIFT + MINUS", hl.dsp.window.resize({ x = -100, y = 0 }))
hl.bind("SUPER + SHIFT + EQUAL", hl.dsp.window.resize({ x = 100, y = 0 }))

-- Floating windows. Nothing above moves one: SUPER+SHIFT+hjkl is a tiling
-- operation, and a floating window has no place in the tree to be moved to.
--
-- window.move with x and y is ABSOLUTE positioning, not a nudge. Passing
-- { x = 120, y = 60 } warps the window to that pixel, and a negative value is
-- dropped as an invalid coordinate rather than moving it left. `relative = true`
-- is what turns it into a delta. `exact = false` looks like the right spelling
-- and does nothing.
for key, d in pairs({ H = { -60, 0 }, J = { 0, 60 }, K = { 0, -60 }, L = { 60, 0 } }) do
  hl.bind("SUPER + CTRL + " .. key, hl.dsp.window.move({ x = d[1], y = d[2], relative = true }))
end

hl.bind("SUPER + CTRL + SPACE", hl.dsp.window.center())

-- Drag to move, right-drag to resize. { mouse = true } is what makes these a
-- held drag rather than a one-shot press, and it is required: this is exactly
-- the form the shipped default at /usr/share/hypr/hyprland.lua uses. Note that
-- `hyprctl binds` reports these with "mouse": false either way, so that output
-- is not a way to check whether the option took.
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- alt-0 cycled desktop themes. bin/theme is on PATH through dotfiles.
hl.bind("SUPER + code:19", hl.dsp.exec_cmd("theme next"))

-- Workspaces: 1-9, the lettered set, and the tab bindings.
dofile(hypr .. "/workspaces.lua")

-- Fn row: brightness, keyboard backlight, volume, mic mute + LED, media keys.
dofile(hypr .. "/media-keys.lua")
