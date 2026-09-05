-- hyprland.lua: day-one Hyprland config for the fresh install. A terminal, a
-- browser, workspaces, and the laptop keys, so the real config can be written
-- on the machine itself. Copy this directory to ~/.config/hypr, or point
-- dotfiles' config/hypr at your own version. Nothing here is meant to last.
--
-- Start from the TTY:   uwsm start hyprland.desktop
-- uwsm runs Hyprland as a user unit and activates graphical-session.target once
-- `uwsm finalize` runs (below), which starts every enabled unit wanted by it:
--   systemctl --user enable hyprpolkitagent hypridle hyprsunset batsignal
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
  general = { gaps_in = 4, gaps_out = 8, border_size = 2, layout = "dwindle" },
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

hl.bind("SUPER + RETURN", app("ghostty"))
hl.bind("SUPER + SHIFT + RETURN", app("chromium"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("loginctl lock-session")) -- hypridle runs hyprlock
hl.bind("SUPER + SHIFT + ESCAPE", hl.dsp.exec_cmd("uwsm stop"))

-- Workspaces 1-9 by keycode (10..18), so the binding survives layout changes.
for ws = 1, 9 do
  local key = "code:" .. tostring(ws + 9)
  hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = tostring(ws) }))
  hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(ws) }))
end

for key, dir in pairs({ H = "l", J = "d", K = "u", L = "r" }) do
  hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = dir }))
  hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))
end

-- Fn row: brightness, keyboard backlight, volume, mic mute + LED, media keys.
dofile(hypr .. "/media-keys.lua")
