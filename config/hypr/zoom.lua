-- Native compositor zoom, bounded to 1–5x. Read the live value so external
-- changes and config reloads don't leave a separate zoom counter out of sync.
local function zoom(delta)
  local current = tonumber(hl.get_config("cursor.zoom_factor")) or 1
  hl.config({ cursor = { zoom_factor = math.max(1, math.min(5, current + delta)) } })
end

-- Shift+equal/minus already resize windows. Reset uses the physical 0 key,
-- since Shift+0 produces a different keysym on the US layout.
hl.bind("SUPER + EQUAL", function() zoom(0.25) end, { repeating = true })
hl.bind("SUPER + MINUS", function() zoom(-0.25) end, { repeating = true })
hl.bind("SUPER + SHIFT + code:19", function()
  hl.config({ cursor = { zoom_factor = 1 } })
end)
hl.bind("SUPER + mouse_up", function() zoom(0.25) end)
hl.bind("SUPER + mouse_down", function() zoom(-0.25) end)
