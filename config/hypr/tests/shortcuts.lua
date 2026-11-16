-- luajit config/hypr/tests/shortcuts.lua config/hypr/hyprland.lua NAMES
-- (shortcuts.sh runs it): the shell's keys are global shortcuts. Executes the
-- real hyprland.lua and every file it loads (launcher-voice.lua, workspaces.lua,
-- ...) with a recording hl, binding nothing and running nothing, and checks:
--   * no bind starts `qs ipc call ...`: each opens or drives its shell surface
--     through hl.dsp.global("quickshell:<name>"), with no process per press
--     (a qs client cost about 64 ms on milhouse before the panel began);
--   * the binds and their options: Super+Space toggles the launcher, its
--     long press holds to talk, the release of Space, Super_L or Super_R stops
--     (release, ignore_mods, submap_universal, non_consuming, as before),
--     Super+V the clipboard, Super+Alt+C the control center, Super+Alt+D the
--     calendar;
--   * Super+Alt+C and Super+Alt+D are bound once, by these binds only;
--   * every quickshell:<name> a bind names has a GlobalShortcut with that name
--     in the shell's QML (NAMES, one per line, which shortcuts.sh collects),
--     so no key dispatches to a shortcut nobody registered.
local config = assert(arg[1], "pass hyprland.lua and the GlobalShortcut names file")
local names_file = assert(arg[2], "pass the GlobalShortcut names file")

local binds = {}
local submap = ""
local noop = function() end
local proxy = setmetatable({}, { __index = function(self) return self end, __call = noop })
local dsp = setmetatable({
  global = function(name) return { kind = "global", arg = name } end,
  exec_cmd = function(cmd) return { kind = "exec", arg = cmd } end,
  submap = function(name) return { kind = "submap", arg = name } end,
}, { __index = function() return proxy end })
hl = setmetatable({
  dsp = dsp,
  bind = function(keys, dispatcher, opts)
    binds[#binds + 1] = { keys = keys, dispatcher = dispatcher, opts = opts or {}, submap = submap }
  end,
  define_submap = function(name, body)
    local outer = submap
    submap = name
    body()
    submap = outer
  end,
  -- No compositor here, so no monitors: main's single-window.lua walks
  -- hl.get_monitors() at load and would stop on nil (its own test runs it
  -- the same way, with none).
  get_monitors = function() return {} end,
}, { __index = function() return proxy end })
io.popen = function() return nil end
local real_dofile = dofile
_G.dofile = function(path)
  if path:match("/launcher%-bindings.lua$") then
    return { begin_registration = noop, end_registration = noop }
  elseif path:match("/current/theme/hyprland.lua$") then
    return nil
  end
  return real_dofile(path)
end
assert(loadfile(config))()

-- "SUPER + ALT + C" and "SUPER+ALT+c" are one chord.
local order = { SUPER = 1, SHIFT = 2, CTRL = 3, CONTROL = 3, ALT = 4 }
local function chord(keys)
  local mods, key = {}, nil
  for token in keys:gmatch("[^%s+]+") do
    local up = token:upper()
    if order[up] and key == nil then mods[#mods + 1] = up == "CONTROL" and "CTRL" or up else key = up end
  end
  table.sort(mods, function(a, b) return order[a] < order[b] end)
  return table.concat(mods, " ") .. " + " .. tostring(key)
end
local function find(keys, test)
  local out = {}
  for _, b in ipairs(binds) do
    if chord(b.keys) == chord(keys) and (not test or test(b)) then out[#out + 1] = b end
  end
  return out
end
local failures = 0
local function check(ok, message)
  if not ok then
    failures = failures + 1
    io.stderr:write("SHORTCUTS_FAIL: " .. message .. "\n")
  end
end
local function plain(b) return not b.opts.release and not b.opts.long_press and b.submap == "" end
local function global(b, name) return type(b.dispatcher) == "table" and b.dispatcher.kind == "global" and b.dispatcher.arg == name end

-- 1. Nothing starts a qs client.
for _, b in ipairs(binds) do
  local d = b.dispatcher
  check(not (type(d) == "table" and d.kind == "exec" and d.arg:find("qs%s+ipc")),
    b.keys .. " still runs `" .. tostring(type(d) == "table" and d.arg) .. "`")
end

-- 2. The shell's binds.
local want = {
  { "SUPER + SPACE", "quickshell:launcher-toggle", plain },
  { "SUPER + V", "quickshell:clipboard-toggle", plain },
  { "SUPER + ALT + C", "quickshell:control-center-toggle", plain },
  { "SUPER + ALT + D", "quickshell:calendar-toggle", plain },
  { "SUPER + SPACE", "quickshell:launcher-voice-hold", function(b) return b.opts.long_press == true and not b.opts.release end },
}
for _, key in ipairs({ "SPACE", "Super_L", "Super_R" }) do
  want[#want + 1] = { key, "quickshell:launcher-voice-release", function(b)
    local o = b.opts
    return o.release == true and o.ignore_mods == true and o.submap_universal == true and o.non_consuming == true
  end }
end
for _, w in ipairs(want) do
  local hits = find(w[1], function(b) return global(b, w[2]) and w[3](b) end)
  check(#hits == 1, w[1] .. " -> " .. w[2] .. " with its options: found " .. #hits)
end

-- 3. The new chords belong to these binds alone.
for _, keys in ipairs({ "SUPER + ALT + C", "SUPER + ALT + D" }) do
  check(#find(keys) == 1, keys .. " is bound " .. #find(keys) .. " times")
end

-- 4. Each global names a registered shortcut.
local registered = {}
for line in io.lines(names_file) do registered[line] = true end
local used = {}
for _, b in ipairs(binds) do
  local d = b.dispatcher
  if type(d) == "table" and d.kind == "global" then
    local appid, name = d.arg:match("^([^:]+):(.+)$")
    check(appid == "quickshell", b.keys .. ": global " .. d.arg .. " is not quickshell's")
    if name then
      check(registered[name], b.keys .. ": no GlobalShortcut named " .. name .. " in the shell")
      used[name] = true
    end
  end
end
local count = 0
for _ in pairs(used) do count = count + 1 end
check(count >= 9, "expected six shell shortcuts and the switcher's three, found " .. count)

if failures > 0 then os.exit(1) end
print("HYPR_SHORTCUTS_PASS " .. count .. " global shortcuts, no qs client per key")
