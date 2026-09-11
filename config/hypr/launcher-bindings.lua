-- Register callbacks deliberately, without inspecting Lua's private registry.
-- Only binds made between begin_registration() and end_registration() belong
-- to this config generation. Keep the public HL.Keybind to check liveness.
local M = {}
local original_bind, wrapper, generation
local entries, ready = {}, false
local MAX_BINDINGS, MAX_OUTPUT = 1024, 262144
local fields = { "handler", "arg", "key", "keycode", "modmask", "submap",
  "release", "long_press", "mouse", "repeating", "catchall", "click", "drag" }

local function token()
  -- Reload destroys the Lua state, so neither a counter nor math.random's
  -- initial seed can distinguish generations. Failure leaves rows disabled.
  local file = io.open("/dev/urandom", "rb")
  if not file then return nil end
  local bytes = file:read(16)
  file:close()
  if not bytes or #bytes ~= 16 then return nil end
  return (bytes:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local function available(entry)
  local bind, identity = entry.bind, entry.identity
  if bind.enabled ~= true or bind:is_enabled() ~= true then return false end
  for _, field in ipairs(fields) do
    if bind[field] ~= identity[field] then return false end
  end
  return identity.handler == "__lua" and not entry.mouse
    and identity.release == false and identity.long_press == false
    and identity.mouse == false and identity.catchall == false
    and identity.click == false and identity.drag == false
    and identity.submap == "" and not identity.key:lower():find("mouse", 1, true)
end

function M.begin_registration()
  if original_bind then M.end_registration() end
  entries, ready, generation = {}, false, token()
  _G.launcher_bindings = M
  original_bind = hl.bind
  wrapper = function(keys, dispatcher, opts)
    local bind = original_bind(keys, dispatcher, opts)
    if bind and #entries < MAX_BINDINGS then
      local identity = {}
      for _, field in ipairs(fields) do identity[field] = bind[field] end
      entries[#entries + 1] = { bind = bind, dispatcher = dispatcher,
        identity = identity, mouse = type(opts) == "table" and not not opts.mouse }
    end
    return bind
  end
  hl.bind = wrapper
end

function M.end_registration()
  if not original_bind then return end
  hl.bind = original_bind
  original_bind, wrapper = nil, nil
  ready = generation ~= nil
end

function M.resolve(expected_generation, id)
  local entry = entries[id]
  if _G.launcher_bindings ~= M or not ready or expected_generation ~= generation
      or not entry or not available(entry) then
    error("launcher binding is stale, unavailable or keyboard-only", 0)
  end
  -- hyprctl dispatch wraps this result in hl.dispatch in the same Lua state.
  -- Return the original HL.Dispatcher/function, never call a numeric Lua ref.
  return entry.dispatcher
end

local function quote(value)
  if type(value) ~= "string" or #value > 256 then error("invalid binding identity", 0) end
  return '"' .. value:gsub('[%z\1-\31\\"]', function(c)
    return string.format("\\u%04x", c:byte())
  end) .. '"'
end

function M.snapshot()
  if not ready or _G.launcher_bindings ~= M then return "{}" end
  -- Native eval uses luaL_tolstring, not a table-to-JSON serializer, and only
  -- its repl mode returns the string. Export identities, never callback code.
  local ok, result = pcall(function()
    local rows, size = {}, 0
    for id, entry in ipairs(entries) do
      if available(entry) then
        local b = entry.identity
        local row = string.format(
          '{"id":%d,"arg":%s,"key":%s,"keycode":%d,"modmask":%d,"submap":%s,"release":false,"longPress":false,"mouse":false,"repeat":%s}',
          id, quote(b.arg), quote(b.key), b.keycode, b.modmask, quote(b.submap), tostring(b.repeating))
        size = size + #row + 1
        if size > MAX_OUTPUT - 128 then return "{}" end
        rows[#rows + 1] = row
      end
    end
    return '{"generation":' .. quote(generation) .. ',"bindings":[' .. table.concat(rows, ",") .. ']}'
  end)
  return ok and result or "{}"
end

return M
