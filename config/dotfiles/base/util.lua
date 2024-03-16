local M = {}

function M.get_current_theme()
  local file = io.open(os.getenv("HOME") .. "/.theme", "r")

  if not file then
    return "catppuccin"
  end

  local content = file:read("*a")
  file:close()

  content = content:gsub("%s+", "")

  return content
end

function M.is_dark_mode()
  local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
  if handle == nil then
    return true
  end
  local result = handle:read("*a")
  handle:close()
  return result:match("^%s*Dark%s*$") ~= nil
end

function M.table_extend(deep, target, ...)
  local arg = { ... }
  for _, t in ipairs(arg) do
    if t then
      for k, v in pairs(t) do
        if deep and type(v) == "table" then
          if type(target[k]) == "table" then
            M.table_extend(deep, target[k], v)
          else
            target[k] = M.table_extend(deep, {}, v)
          end
        else
          target[k] = v
        end
      end
    end
  end
  return target
end

function M.file_exists(name)
  local f = io.open(name, "r")
  return f ~= nil and io.close(f)
end

function M.debounce(ms, fn)
  local timer = vim.loop.new_timer()
  return function(...)
    local argv = { ... }
    timer:start(ms, 0, function()
      timer:stop()
      vim.schedule_wrap(fn)(unpack(argv))
    end)
  end
end

function M.has_module(name)
  if pcall(function()
    require(name)
  end) then
    return true
  else
    return false
  end
end

return M
