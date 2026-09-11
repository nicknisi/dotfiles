-- lua config/hypr/tests/style.lua config/hypr/hyprland.lua themes/*/hyprland.lua
-- Execute the real config and pack overrides, without registering bindings or
-- running monitor, process or workspace commands on the desktop.
local config = assert(arg[1], "pass hyprland.lua and theme files")
local real_dofile = dofile
local state, pack, themed_borders, pack_loaded
local noop = function() end
local proxy = setmetatable({}, { __index = function(self) return self end, __call = noop })
local function merge(into, values)
  for key, value in pairs(values) do
    if type(value) == "table" then
      if type(into[key]) ~= "table" then into[key] = {} end
      merge(into[key], value)
    else
      into[key] = value
    end
  end
end
hl = setmetatable({ config = function(values) merge(state, values) end }, { __index = function() return proxy end })
io.popen = function() return nil end
_G.dofile = function(path)
  if path:match("/launcher%-bindings.lua$") then
    return { begin_registration = noop, end_registration = noop }
  elseif path:match("/current/theme/hyprland.lua$") and pack then
    real_dofile(pack)
    pack_loaded = true
    themed_borders = state.general.col and state.general.col.active_border
  end
end

-- No theme, each pack, then no theme again to check stale coloured shadows.
state = {}
for i = 1, #arg + 1 do
  pack = i > 1 and arg[i] or nil
  themed_borders, pack_loaded = nil, false
  assert(loadfile(config))()
  assert(not pack or pack_loaded, "theme failed to load: " .. tostring(pack))
  local decoration = state.decoration
  assert(decoration.rounding == 6 and decoration.rounding_power == 2, "window shape: " .. tostring(pack))
  assert(decoration.shadow.enabled and decoration.shadow.range == 16 and decoration.shadow.render_power == 3, "shadow geometry")
  assert(decoration.shadow.color == "rgba(00000030)" and decoration.shadow.color_inactive == "rgba(00000030)", "neutral shadows")
  if themed_borders then
    assert(state.general.col.active_border == themed_borders, "preserve the pack's active border")
  end
end
print("THEME_STYLE_PASS")
