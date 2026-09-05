-- media-keys.lua: the Fn row on the Dell XPS 14 (DA14260) for Hyprland's Lua
-- config. No shell involved: brightnessctl, wpctl and playerctl do the work,
-- so this survives whatever bar or OSD you end up with. hyprland.lua loads it
-- with dofile; from a require-based config add ~/.config/hypr to package.path.
--
-- Who handles what on this laptop:
--   firmware   Fn lock, airplane mode (rfkill; kernel CONFIG_RFKILL_INPUT=y),
--              power key long press
--   kernel     dell_wmi / dell_laptop turn the Fn row into XF86* keysyms;
--              keyboard backlight LED: /sys/class/leds/dell::kbd_backlight (0..2)
--              mic-mute LED:           /sys/class/leds/platform::micmute
--   logind     power key -> suspend (etc/systemd/logind.conf.d/10-power-button.conf).
--              Not bound here on purpose: binding it as well fires both.
--   Hyprland   everything below
--
-- Needs: brightnessctl (goes through logind, no video group), wireplumber
-- (wpctl), playerctl. No OSD: if you want one, install swayosd and wrap these
-- commands with swayosd-client.

local locked = { locked = true }
local locked_repeating = { locked = true, repeating = true }
local function cmd(s) return hl.dsp.exec_cmd(s) end

local function read_num(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local v = tonumber(f:read("*l"))
  f:close()
  return v
end

-- Display brightness. 5% steps, floor at 1% in raw units so a step down from
-- 5% never blanks the OLED (intel_backlight is 0..512 here; 5%- from 4% = 0).
local bl_max = read_num("/sys/class/backlight/intel_backlight/max_brightness") or 512
local bl_floor = math.max(1, math.floor(bl_max / 100))
local function bl_down(step)
  return cmd(string.format(
    "sh -c 'brightnessctl -q set %s-; [ \"$(brightnessctl get)\" -lt %d ] && brightnessctl -q set %d'",
    step, bl_floor, bl_floor))
end
hl.bind("XF86MonBrightnessUp",           cmd("brightnessctl -q set 5%+"), locked_repeating)
hl.bind("XF86MonBrightnessDown",         bl_down("5%"),                    locked_repeating)
hl.bind("ALT + XF86MonBrightnessUp",     cmd("brightnessctl -q set 1%+"), locked_repeating)
hl.bind("ALT + XF86MonBrightnessDown",   bl_down("1%"),                    locked_repeating)
hl.bind("SHIFT + XF86MonBrightnessUp",   cmd("brightnessctl -q set 100%"), locked)
hl.bind("SHIFT + XF86MonBrightnessDown", cmd("brightnessctl -q set " .. bl_floor), locked)

-- Keyboard backlight. The Dell key sends XF86KbdLightOnOff (one key cycles
-- off / half / full); external keyboards send Up/Down. Steps are a tenth of
-- the range, at least 1, which on this 0..2 LED means one level per press.
local kbd_max = read_num("/sys/class/leds/dell::kbd_backlight/max_brightness") or 2
local kbd_step = math.max(1, math.floor(kbd_max / 10))
local kbd = "brightnessctl -q -d dell::kbd_backlight "
hl.bind("XF86KbdLightOnOff", cmd(string.format(
  "sh -c 'c=$(brightnessctl -d dell::kbd_backlight get); n=$((c + %d)); [ $n -gt %d ] && n=0; %sset $n'",
  kbd_step, kbd_max, kbd)), locked)
hl.bind("XF86KbdBrightnessUp",   cmd(kbd .. "set " .. kbd_step .. "+"), locked_repeating)
hl.bind("XF86KbdBrightnessDown", cmd(kbd .. "set " .. kbd_step .. "-"), locked_repeating)

-- Volume, capped at 100%. Raising also unmutes, like Omarchy did.
local sink = "@DEFAULT_AUDIO_SINK@"
local function vol_up(step)
  return cmd("sh -c 'wpctl set-mute " .. sink .. " 0; wpctl set-volume -l 1.0 " .. sink .. " " .. step .. "+'")
end
hl.bind("XF86AudioRaiseVolume",       vol_up("5%"),                                   locked_repeating)
hl.bind("XF86AudioLowerVolume",       cmd("wpctl set-volume " .. sink .. " 5%-"),     locked_repeating)
hl.bind("ALT + XF86AudioRaiseVolume", vol_up("1%"),                                   locked_repeating)
hl.bind("ALT + XF86AudioLowerVolume", cmd("wpctl set-volume " .. sink .. " 1%-"),     locked_repeating)
hl.bind("XF86AudioMute",              cmd("wpctl set-mute " .. sink .. " toggle"),    locked)

-- Mic mute, mirrored onto the F4 key's LED, which nothing else drives.
hl.bind("XF86AudioMicMute", cmd(
  "sh -c 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle; "
  .. "if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; "
  .. "then brightnessctl -q -d platform::micmute set 1; "
  .. "else brightnessctl -q -d platform::micmute set 0; fi'"), locked)

-- Media keys (MPRIS).
hl.bind("XF86AudioPlay",  cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioPause", cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioNext",  cmd("playerctl next"),       locked)
hl.bind("XF86AudioPrev",  cmd("playerctl previous"),   locked)
hl.bind("XF86AudioStop",  cmd("playerctl stop"),       locked)

-- Not bound on purpose:
--   XF86PowerOff   logind suspends (see the header). For a power menu, flip
--                  the drop-in to HandlePowerKey=ignore and bind it here.
--   XF86Display    (F8) bind it to your monitor tool if you want one.
