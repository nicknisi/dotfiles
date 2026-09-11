-- hyprland.lua: day-one Hyprland config for the fresh install. A terminal, a
-- browser, workspaces, and the laptop keys, so the real config can be written
-- on the machine itself. Copy this directory to ~/.config/hypr, or point
-- dotfiles' config/hypr at your own version. Nothing here is meant to last.
--
-- Start from the TTY:   uwsm start hyprland.desktop
-- uwsm runs Hyprland as a user unit and activates graphical-session.target once
-- `uwsm finalize` runs (below), which starts every enabled unit wanted by it:
--   systemctl --user enable hyprpolkitagent hypridle hyprsunset batsignal
-- quickshell ships no unit of its own; ~/.config/systemd/user/quickshell.service
-- is machine-local, since mise's [dotfiles] would symlink a tracked config/systemd
-- and systemctl would then write its .wants links back into the repo.
-- Exit with SUPER+SHIFT+Escape (`uwsm stop`), not by killing Hyprland.
--
-- The hl.* API here (hl.config / hl.bind / hl.dsp.*) is Hyprland 0.56's Lua
-- config. Two things worth knowing:
--   * `hyprctl dispatch` takes Lua too:  hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'
--     The old `hyprctl dispatch dpms off` form is a parse error on 0.56.
--   * Launch apps through `uwsm-app -- <cmd>` so they get their own scope and
--     outlive a compositor restart cleanly.

-- Files next to this one (media-keys.lua) load relative to it, so the config
-- can be verified from a checkout: Hyprland --verify-config -c path/to/hyprland.lua
local hypr = (debug and debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$"))
  or (os.getenv("HOME") .. "/.config/hypr")
local launcher_bindings = dofile(hypr .. "/launcher-bindings.lua")
launcher_bindings.begin_registration()

-- 2880x1800 OLED at 1.6 = 1800x1125 logical, GDK_SCALE 2.
hl.env("GDK_SCALE", "2")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.6 })
local display_state = os.getenv("HOME") .. "/.local/state/display-mode"
local display_files = io.popen("ls " .. display_state .. "/*.lua 2>/dev/null")
if display_files then
  for file in display_files:lines() do pcall(dofile, file) end
  display_files:close()
end

-- dotfiles/bin (theme and friends) is added to PATH by .zshrc, which only
-- runs for interactive shells. Hyprland is started from a TTY by uwsm and never
-- sources it, so exec_cmd runs with the bare login PATH and cannot find any of
-- them -- silently, since a failed exec reports nothing.
-- Guarded because hyprctl reload re-runs this file and os.getenv("PATH") already
-- reflects the previous hl.env, so an unconditional append grows the variable by
-- one copy per reload.
local dotfiles_bin = os.getenv("HOME") .. "/Developer/dotfiles/bin"
local current_path = os.getenv("PATH") or ""
if not current_path:find(dotfiles_bin, 1, true) then
  hl.env("PATH", current_path .. ":" .. dotfiles_bin)
end

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

  -- preserve_split is what makes a split direction stick once set. Without it
  -- dwindle recomputes the direction from the container's aspect ratio on every
  -- layout pass, silently undoing togglesplit: SUPER+SLASH appeared to do
  -- nothing, and moving a stacked window sideways with SUPER+SHIFT+L could not
  -- work either because there was never a stack to begin with.
  --
  -- force_split stays at its default 0: a new window splits on whichever half of
  -- the focused window the cursor is over. Set 1 for always left/above, 2 for
  -- always right/below if that is too fiddly.
  dwindle = {
    preserve_split = true,
  },
  decoration = { blur = { enabled = true } },
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace", scale = 0.5 })
hl.gesture({ fingers = 4, direction = "horizontal", action = "scroll_move" })

-- The 8ds default takes 800ms. Keep the motion, but get it out of the way.
hl.animation({ leaf = "global", enabled = true, speed = 2.5, bezier = "default" })
hl.curve("workspaceSettle", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "workspaceSettle" })

hl.device({
  name = "protoarc-xk01-tp-mouse",
  natural_scroll = true,
})

hl.on("hyprland.start", function()
  -- Hand WAYLAND_DISPLAY & co. to the user manager and D-Bus; uwsm then
  -- activates graphical-session.target. Hyprland does not do this by itself.
  hl.exec_cmd("uwsm finalize")
  hl.exec_cmd("uwsm-app -- awww-daemon --quiet")
  hl.exec_cmd("uwsm-app -- udiskie --automount --no-notify --no-tray")
end)

local function app(command) return hl.dsp.exec_cmd("uwsm-app -- " .. command) end

-- The launcher already lives inside Quickshell, so this only sends its toggle
-- message. It gives each chosen app its own uwsm scope before disappearing.
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
pcall(dofile, hypr .. "/launcher-voice.lua")
-- Global clipboard history. Ctrl+Shift+V remains direct terminal paste.
hl.bind("SUPER + V", hl.dsp.exec_cmd([[
  qs ipc call clipboard toggle "$(hyprctl activeworkspace -j | jq -r .monitor)"
]]))

-- Capture. The launcher exposes every target; these are the fast paths.
hl.bind("PRINT",                   hl.dsp.exec_cmd("capture shot region"))
hl.bind("SHIFT + PRINT",           hl.dsp.exec_cmd("capture shot screen"))
hl.bind("ALT + PRINT",             hl.dsp.exec_cmd("capture annotate region"))
hl.bind("SUPER + PRINT",           hl.dsp.exec_cmd("capture record region"))
hl.bind("SUPER + SHIFT + PRINT",   hl.dsp.exec_cmd("capture record stop"))

hl.bind("SUPER + RETURN", app("ghostty"))
hl.bind("SUPER + SHIFT + RETURN", hl.dsp.exec_cmd("sh -c 'uwsm-app -- \"$(xdg-settings get default-web-browser)\"'"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("loginctl lock-session")) -- hypridle runs hyprlock
hl.bind("SUPER + SHIFT + ESCAPE", hl.dsp.exec_cmd("uwsm stop"))

-- Focus, move and resize. The move and resize halves both need more than a
-- bare dispatcher, so they live in their own file.
dofile(hypr .. "/windows.lua")

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

local function workspace_selector(ws)
  if ws.name and ws.name ~= "" and ws.name ~= tostring(ws.id) then
    if ws.name:match("^name:") or ws.name:match("^special:") then return ws.name end
    return "name:" .. ws.name
  end
  return tostring(ws.id)
end

local function toggle_workspace_layout()
  local ws = hl.get_active_special_workspace() or hl.get_active_workspace()
  if not ws then return end

  hl.workspace_rule({
    workspace = workspace_selector(ws),
    layout = ws.tiled_layout == "scrolling" and "dwindle" or "scrolling",
  })
end

hl.bind("SUPER + ALT + L", toggle_workspace_layout)

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

-- Theme. bin/theme is on PATH through dotfiles (see the PATH note above).
-- code:19 is the 0 key: alt-0 cycled desktop themes in the aerospace days.
hl.bind("SUPER + code:19", hl.dsp.exec_cmd("theme next"))
hl.bind("SUPER + CTRL + code:19", hl.dsp.exec_cmd("theme bg next"))

-- Border colours come from the active theme: bin/theme renders
-- themes/templates/hyprland.lua.tpl (or the pack's own hyprland.lua) into the
-- state dir and runs `hyprctl reload`. pcall so a machine where theme has never
-- run still gets a working config, with Hyprland's default borders.
pcall(dofile, os.getenv("HOME") .. "/.local/state/theme/current/theme/hyprland.lua")

-- Packs own border colours. Keep shape and depth consistent even when a pack
-- supplies its own decoration settings, including on a full config reload.
hl.config({
  decoration = {
    rounding = 6,
    rounding_power = 2.0,
    shadow = {
      enabled = true,
      range = 16,
      render_power = 3,
      color = "rgba(00000030)",
      color_inactive = "rgba(00000030)",
    },
  },
})

-- Workspaces: 1-9, the lettered set, and the tab bindings.
dofile(hypr .. "/workspaces.lua")

-- Fn row: brightness, keyboard backlight, volume, mic mute + LED, media keys.
dofile(hypr .. "/media-keys.lua")
launcher_bindings.end_registration()
