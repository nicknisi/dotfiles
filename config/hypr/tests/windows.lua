-- lua config/hypr/tests/windows.lua
local active, windows, calls, binds, effect = nil, {}, {}, {}, nil
local function dispatcher(kind, args)
  return { kind = kind, args = args or {} }
end
hl = {
  get_active_window = function()
    return active
  end,
  get_windows = function()
    return windows
  end,
  bind = function(key, callback)
    binds[key] = callback
  end,
  dispatch = function(call)
    calls[#calls + 1] = call
    if effect then
      effect(call)
    end
  end,
  dsp = {
    window = {
      move = function(args)
        return dispatcher("move", args)
      end,
      resize = function(args)
        return dispatcher("resize", args)
      end,
    },
    focus = function(args)
      return dispatcher("focus", args)
    end,
    layout = function(name)
      return dispatcher("layout", { name = name })
    end,
    group = {
      next = function()
        return dispatcher("next")
      end,
      prev = function()
        return dispatcher("prev")
      end,
    },
  },
}
dofile("config/hypr/windows.lua")
local function window(layout, group)
  return {
    address = "one",
    floating = false,
    group = group,
    workspace = { id = 1, tiled_layout = layout },
    at = { x = 0, y = 0 },
    size = { x = 500, y = 500 },
  }
end
local function press(key)
  calls, effect = {}, nil
  binds[key]()
end
for key, dir in pairs({ H = "l", J = "d", K = "u", L = "r" }) do
  active = window("dwindle")
  press("SUPER + SHIFT + " .. key)
  assert(#calls == 1 and calls[1].args.into_or_create_group == dir, "join/create toward " .. dir)
  active.group = { size = 1 }
  press("SUPER + SHIFT + " .. key)
  assert(#calls == 1 and calls[1].args.into_or_create_group == dir, "singleton group can join")
  active.group = { size = 3, current_index = 2 }
  press("SUPER + SHIFT + " .. key)
  assert(#calls == 3 and calls[2].args.out_of_group == dir, "extract active tab toward " .. dir)
  assert(
    calls[1].args.name == "preselect " .. dir and calls[3].args.name == "preselect x",
    "force and reset split direction"
  )
  active.floating = true
  press("SUPER + SHIFT + " .. key)
  assert(#calls == 1 and calls[1].args.direction == dir, "floating movement unchanged")
  active = window("scrolling", { size = 3, current_index = 2 })
  press("SUPER + SHIFT + " .. key)
  assert(#calls == 1 and calls[1].args.direction == dir, "scrolling movement unchanged")
end
active = window("dwindle", { size = 3, current_index = 2 })
press("SUPER + J")
assert(#calls == 1 and calls[1].kind == "next", "J selects next tab")
press("SUPER + K")
assert(#calls == 1 and calls[1].kind == "prev", "K selects previous tab")
press("SUPER + H")
assert(#calls == 1 and calls[1].kind == "focus" and calls[1].args.direction == "l", "H remains spatial")
press("SUPER + L")
assert(#calls == 1 and calls[1].kind == "focus" and calls[1].args.direction == "r", "L remains spatial")
active.group.current_index = 3
press("SUPER + J")
assert(#calls == 2 and calls[1].kind == "focus" and calls[2].kind == "next", "wrap only after spatial exit fails")
active.group.current_index = 1
press("SUPER + K")
assert(#calls == 2 and calls[1].kind == "focus" and calls[2].kind == "prev", "reverse wrap")
calls = {}
effect = function(call)
  if call.kind == "focus" then
    active = window("dwindle")
    active.address = "neighbor"
  end
end
binds["SUPER + K"]()
assert(#calls == 1 and active.address == "neighbor", "leave group at edge when a spatial target exists")
active = window("scrolling", { size = 3, current_index = 2 })
press("SUPER + J")
assert(#calls == 1 and calls[1].kind == "focus", "scrolling focus unchanged")
active = nil
press("SUPER + SHIFT + H")
assert(#calls == 0, "no focused window is safe")
print("WINDOWS_PASS")
