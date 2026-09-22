-- lua config/hypr/tests/zoom.lua
local value, binds = 1, {}
hl = {
  get_config = function(key)
    assert(key == "cursor.zoom_factor")
    return value
  end,
  config = function(update) value = update.cursor.zoom_factor end,
  bind = function(key, fn, opts)
    assert(not binds[key], "duplicate binding")
    binds[key] = { fn = fn, opts = opts or {} }
  end,
}
dofile("config/hypr/zoom.lua")
local function press(key, expected)
  binds[key].fn()
  assert(value == expected, key .. ": expected " .. expected .. ", got " .. tostring(value))
end
press("SUPER + EQUAL", 1.25)
press("SUPER + MINUS", 1)
press("SUPER + MINUS", 1)
value = 4.9
press("SUPER + EQUAL", 5)
press("SUPER + mouse_up", 5)
press("SUPER + mouse_down", 4.75)
press("SUPER + SHIFT + code:19", 1)
value = false
press("SUPER + EQUAL", 1.25)
assert(binds["SUPER + EQUAL"].opts.repeating)
assert(binds["SUPER + MINUS"].opts.repeating)
print("ZOOM_PASS")
