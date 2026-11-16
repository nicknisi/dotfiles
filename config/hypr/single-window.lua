-- Match bin/omniwm-monitors: a lone tile is 5/6 of the display wide and 80%
-- tall, rounded to 10 logical pixels and centered in the area below the bar.
local rules = {}
local function update()
  local seen = {}
  local border = hl.get_config("general.border_size")
  for _, m in ipairs(hl.get_monitors()) do
    seen[m.name] = true
    local w, h = m.width / m.scale, m.height / m.scale
    if m.transform % 2 == 1 then
      w, h = h, w
    end
    local r = m.reserved
    local usable_w = w - r.left - r.right
    local usable_h = h - r.top - r.bottom
    local target_w = math.floor(w * (5 / 6) / 10 + 0.5) * 10
    local target_h = math.floor(h * 0.8 / 10 + 0.5) * 10
    local x = math.max(8, math.floor((usable_w - target_w) / 2) - border)
    local y = math.max(8, math.floor((usable_h - target_h) / 2) - border)
    local old = rules[m.name]
    if not old or old.x ~= x or old.y ~= y then
      if old then
        old.rule:set_enabled(false)
      end
      rules[m.name] = {
        x = x,
        y = y,
        rule = hl.workspace_rule({
          workspace = "m[" .. m.name .. "]w[tv1]s[false]f[-1]",
          gaps_in = 0,
          gaps_out = { top = y, right = x, bottom = y, left = x },
        }),
      }
    end
  end
  for name, old in pairs(rules) do
    if not seen[name] then
      old.rule:set_enabled(false)
      rules[name] = nil
    end
  end
end
hl.on("config.reloaded", update)
hl.on("config.props_refreshed", update)
hl.on("monitor.layout_changed", update)
update()
