-- lua config/hypr/tests/single-window.lua
local monitors, callbacks, rules = {}, {}, {}
hl = {
  get_config = function(key)
    assert(key == "general.border_size")
    return 2
  end,
  get_monitors = function()
    return monitors
  end,
  on = function(event, callback)
    callbacks[event] = callback
  end,
  workspace_rule = function(spec)
    spec.enabled = true
    function spec:set_enabled(value)
      self.enabled = value
    end
    rules[#rules + 1] = spec
    return spec
  end,
}
dofile("config/hypr/single-window.lua")
assert(#rules == 0, "config verification can run without monitors")
local function monitor(name, width, height, scale, top, transform)
  return {
    name = name,
    width = width,
    height = height,
    scale = scale,
    transform = transform or 0,
    reserved = { top = top, right = 0, bottom = 0, left = 0 },
  }
end
local function geometry(rule, m, target_w, target_h)
  assert(
    rule.workspace == "m[" .. m.name .. "]w[tv1]s[false]f[-1]",
    "only one visible tile, no special/fullscreen workspaces"
  )
  assert(rule.gaps_in == 0, "no scrolling-layout inner gaps around a lone tile")
  local w, h = m.width / m.scale, m.height / m.scale
  if m.transform % 2 == 1 then
    w, h = h, w
  end
  local g, r = rule.gaps_out, m.reserved
  assert(g.left == g.right and g.top == g.bottom, "center within usable area")
  assert(math.abs(w - r.left - r.right - g.left - g.right - 4 - target_w) <= 1, "width")
  assert(math.abs(h - r.top - r.bottom - g.top - g.bottom - 4 - target_h) <= 1, "height")
end
monitors = { monitor("eDP-1", 2880, 1800, 1.5, 46), monitor("DP-1", 3840, 2160, 1, 40) }
callbacks["config.reloaded"]()
geometry(rules[1], monitors[1], 1600, 960)
geometry(rules[2], monitors[2], 3200, 1730)
callbacks["monitor.layout_changed"]()
assert(#rules == 2, "unchanged geometry does not add rules")
monitors[1].scale = 1.6
callbacks["monitor.layout_changed"]()
assert(not rules[1].enabled and rules[2].enabled, "replace only changed display's rule")
geometry(rules[3], monitors[1], 1500, 900)
monitors = { monitors[1] }
callbacks["monitor.layout_changed"]()
assert(not rules[2].enabled, "disable disconnected display's rule")
monitors[1] = monitor("eDP-1", 2880, 1800, 1.5, 46, 1)
callbacks["monitor.layout_changed"]()
geometry(rules[4], monitors[1], 1000, 1540)
monitors[1].reserved.top = 1000
callbacks["config.props_refreshed"]()
assert(rules[5].gaps_out.top == 8, "clamp to normal gaps when usable space is too small")
print("SINGLE_WINDOW_PASS")
