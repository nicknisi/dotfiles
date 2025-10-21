local M = {}
local wezterm = require("wezterm")
local appearance = wezterm.gui.get_appearance()

M.is_dark = appearance:find("Dark")

M.get_random_entry = function(tbl)
  local keys = {}
  for key, _ in pairs(tbl) do
    table.insert(keys, key)
  end
  local random_key = keys[math.random(#keys)]
  return tbl[random_key]
end

return M
