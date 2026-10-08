local M = {}

---Determine whether the active theme is dark. bin/theme writes the pack's
---mode to ~/.local/state/theme/current/mode on every switch; that wins on
---every platform. Without it, macOS follows the system appearance and
---anything else (a server) is assumed dark.
---@return boolean is_dark Whether the active theme is dark
function M.is_dark_mode()
  local f = io.open(vim.fn.expand("~/.local/state/theme/current/mode"), "r")
  if f then
    local mode = f:read("*l")
    f:close()
    if mode == "light" then
      return false
    elseif mode == "dark" then
      return true
    end
  end
  if vim.fn.has("mac") == 1 then
    local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
    if handle == nil then
      return true
    end
    local result = handle:read("*a")
    handle:close()
    return result:match("^%s*Dark%s*$") ~= nil
  else
    -- If not on macos, then assume we're on a server and should default to dark
    return true
  end
end

---Copy the current block of text to the system clipboard with normalized indentation
function M.copy_normalized_block()
  local mode = vim.fn.mode()

  if mode ~= "v" and mode ~= "V" then
    return
  end

  vim.cmd([[silent normal! "xy]])
  local text = vim.fn.getreg("x")
  local lines = vim.split(text, "\n", { plain = true })

  local converted = {}
  for _, line in ipairs(lines) do
    local l = line:gsub("\t", " ")
    table.insert(converted, l)
  end

  local min_indent = math.huge
  for _, line in ipairs(converted) do
    if line:match("[^%s]") then
      local indent = #(line:match("^%s*"))
      min_indent = math.min(min_indent, indent)
    end
  end

  min_indent = min_indent == math.huge and 0 or min_indent

  local result = {}
  for _, line in ipairs(converted) do
    if line:match("^%s*$") then
      table.insert(result, "")
    else
      local processed = line:sub(min_indent + 1)
      processed = processed:gsub("^%s+", function(spaces)
        return string.rep("  ", math.floor(#spaces / 2))
      end)
      table.insert(result, processed)
    end
  end

  local normalized = table.concat(result, "\n")
  vim.fn.setreg("+", normalized)
  vim.notify("Copied normalized text to clipboard")
end

return M
