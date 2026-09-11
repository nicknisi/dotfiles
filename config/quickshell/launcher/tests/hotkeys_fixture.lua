-- Run with LuaJIT. All compositor APIs are mocks, including dispatch.
local module_path = assert(arg[1], "path to launcher-bindings.lua required")
local native_id, submap, calls = 40, "", 0
local objects = {}
local function native_bind(key, dispatcher, opts)
  opts = opts or {}
  assert(type(dispatcher) == "function" or type(dispatcher) == "table")
  native_id = native_id + 1
  local bind = { key = key, keycode = 0, modmask = 64, submap = submap,
    handler = "__lua", arg = tostring(native_id), enabled = true,
    release = not not (opts.release or opts.click or opts.drag),
    long_press = not not opts.long_press, repeating = not not opts.repeating,
    -- Native hl.bind currently ignores opts.mouse. The wrapper must retain it.
    mouse = false, catchall = false, click = not not opts.click, drag = not not opts.drag }
  function bind:is_enabled() return self.enabled end
  function bind:set_enabled(value) self.enabled = value end
  function bind:remove() self.arg = "-2" end -- may still be held by a pressed key
  objects[#objects + 1] = bind
  return bind
end
hl = { bind = native_bind }
function hl.dispatch(dispatcher)
  if type(dispatcher) == "function" then return dispatcher() end
  assert(type(dispatcher) == "table" and dispatcher.call)
  return dispatcher.call()
end
local function callback() calls = calls + 1 end
local dispatcher = { call = callback }

local function begin()
  local registry = dofile(module_path)
  registry.begin_registration()
  assert(hl.bind ~= native_bind)
  assert(_G.launcher_bindings == registry)
  assert(registry.snapshot() == "{}") -- partial config never runnable
  return registry
end
local function generation(registry)
  return assert(registry.snapshot():match('"generation":"([0-9a-f]+)"'))
end
local function rejected(registry, gen, id)
  local before = calls
  assert(not pcall(function() hl.dispatch(registry.resolve(gen, id)) end))
  assert(calls == before)
end
local registry = begin()
local first = hl.bind("Q", dispatcher)
assert(first == objects[#objects]) -- preserve the returned public object
local second = hl.bind("F", callback)
local repeating = hl.bind("R", callback, { repeating = true })
local excluded = {
  hl.bind("SPACE", callback, { release = true }),
  hl.bind("SPACE", callback, { long_press = true }),
  hl.bind("mouse:272", dispatcher),
  hl.bind("M", dispatcher, { mouse = true }),
  hl.bind("C", callback, { click = true }),
  hl.bind("D", callback, { drag = true }),
}
submap = "resize"
excluded[#excluded + 1] = hl.bind("S", callback)
submap = ""
registry.end_registration()
assert(hl.bind == native_bind)
local gen = generation(registry)
assert(#gen == 32)
assert(registry.resolve(gen, 1) == dispatcher)
assert(registry.resolve(gen, 2) == callback)
assert(calls == 0) -- snapshot and resolve are read-only
hl.dispatch(registry.resolve(gen, 1))
hl.dispatch(registry.resolve(gen, 2))
hl.dispatch(registry.resolve(gen, 3)) -- repeat is safe to run once
assert(calls == 3)
for id = 4, 3 + #excluded do rejected(registry, gen, id) end
rejected(registry, "wrong-generation", 1)
rejected(registry, gen, 999)
rejected(registry, gen, first.arg) -- native arg is NOT our registration ID
rejected(registry, gen, '1); error("injected")')
local opaque = hl.bind("O", callback)
assert(not registry.snapshot():find('"arg":"' .. opaque.arg .. '"', 1, true))
rejected(registry, gen, 4 + #excluded)

first:set_enabled(false)
rejected(registry, gen, 1)
assert(not registry.snapshot():find('"id":1,', 1, true))
first:set_enabled(true)
assert(registry.resolve(gen, 1) == dispatcher)
-- Every public identity component is rechecked at activation, not just load.
for _, field in ipairs({ "handler", "arg", "key", "keycode", "modmask", "submap", "release", "long_press", "mouse", "repeating", "catchall", "click", "drag" }) do
  local saved = first[field]
  first[field] = type(saved) == "boolean" and not saved or "changed"
  rejected(registry, gen, 1)
  first[field] = saved
end
first:remove()
rejected(registry, gen, 1)
-- Expired weak HL.Keybind objects expose nil fields/is_enabled().
second.enabled = nil
rejected(registry, gen, 2)
local previous_registry = registry
registry = begin() -- a fresh module, as on a fresh Lua state
native_id = 40 -- deliberately recycle native callback args AND our IDs
hl.bind("Q", function() calls = calls + 100 end)
registry.end_registration()
assert(generation(registry) ~= gen)
rejected(registry, gen, 1)
rejected(previous_registry, gen, 3)
-- Reusing the module for a new registration scope also rotates the token.
local previous_gen = generation(registry)
registry.begin_registration()
hl.bind("Q", callback)
registry.end_registration()
assert(generation(registry) ~= previous_gen)
rejected(registry, previous_gen, 1)

-- Bound the serialized data and escape strings instead of returning tables
-- (native eval's luaL_tolstring would only return a table address).
registry = begin()
hl.bind('quote"\\\n\t\0', callback)
registry.end_registration()
local json = registry.snapshot()
assert(json:find('quote\\u0022\\u005c\\u000a\\u0009\\u0000', 1, true))
assert(#json < 262144)
registry = begin()
for _ = 1, 103 do hl.bind("Q", callback) end
registry.end_registration()
local count = 0
for _ in registry.snapshot():gmatch('"id":') do count = count + 1 end
assert(count == 103)
registry = begin()
for _ = 1, 1100 do hl.bind("Q", callback) end
registry.end_registration()
count = 0
for _ in registry.snapshot():gmatch('"id":') do count = count + 1 end
assert(count == 1024)
assert(#registry.snapshot() <= 262144)
registry = begin()
for _ = 1, 1024 do hl.bind(string.rep('"', 256), callback) end
registry.end_registration()
assert(registry.snapshot() == "{}") -- oversize response fails closed
local open = io.open
io.open = function() return nil end
registry = begin()
io.open = open
hl.bind("Q", callback)
registry.end_registration()
assert(hl.bind == native_bind and registry.snapshot() == "{}")
rejected(registry, "", 1)

if arg[2] == "--bridge" then
  -- The helper normalizes this Lua snapshot and sends the resulting fixed
  -- resolver expression back. Emulate native dispatch's same-state wrapper.
  registry = begin()
  hl.bind("Q", dispatcher)
  registry.end_registration()
  print(registry.snapshot())
  io.stdout:flush()
  local expression = assert(io.read("*l"))
  local execute = assert(load("return hl.dispatch(" .. expression .. ")", "fixture dispatch", "t", { hl = hl, _G = _G }))
  local before = calls
  execute()
  assert(calls == before + 1)
  registry.begin_registration()
  hl.bind("Q", function() calls = calls + 100 end)
  registry.end_registration()
  assert(not pcall(execute)) -- cached action cannot execute the changed callback
  assert(calls == before + 1)
end
print("HOTKEYS_LUA_PASS")
