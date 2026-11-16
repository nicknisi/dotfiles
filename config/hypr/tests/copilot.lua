-- lua config/hypr/tests/copilot.lua
-- The Copilot key's latch (media-keys.lua) and the island's Stop button:
-- stopping through voxtype_copilot_stop() clears the latch, so the next
-- Copilot press starts a new session instead of stopping the ended one.
local binds, ran, submap = {}, {}, "reset"
hl = {
  bind = function(key, fn, opts)
    local o = opts or {}
    local k = key .. (o.release and " (release)" or "")
    binds[k] = { fn = fn, opts = o }
  end,
  define_submap = function(name, fn) fn() end,
  dispatch = function(d)
    if d.cmd then ran[#ran + 1] = d.cmd end
    if d.submap then submap = d.submap end
  end,
  dsp = {
    exec_cmd = function(s) return { cmd = s } end,
    submap = function(name) return { submap = name } end,
  },
}
io.open = function() return nil end -- no /sys reads
dofile("config/hypr/media-keys.lua")

local function press(key)
  ran = {}
  binds[key].fn()
  return ran[#ran]
end

-- Hold Copilot, press Space: latched, still recording after the key comes up.
assert(press("SUPER + SHIFT + code:201") == "voxtype record start")
assert(submap == "voxtype_copilot")
press("SPACE")
assert(submap == "reset")
assert(press("code:201 (release)") == nil, "a latched session survives the release")

-- The island's Stop: through Hyprland, so the latch goes with the session.
assert(type(voxtype_copilot_stop) == "function", "voxtype_copilot_stop is global")
ran = {}
voxtype_copilot_stop()
assert(ran[1] == "voxtype record stop", "it stops voxtype")
assert(submap == "reset")

-- The next press starts dictating at once (no second press needed).
assert(press("SUPER + SHIFT + code:201") == "voxtype record start", "the next press starts a session")
press("code:201 (release)")
assert(press("Control_R") == "voxtype record start", "Right Control mirrors it")
print("COPILOT_PASS")
