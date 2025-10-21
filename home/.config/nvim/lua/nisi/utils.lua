local api = vim.api
---@class NeoUtils
local M = {}

function M.has_map(map, mode)
  mode = mode or "n"
  return vim.fn.maparg(map, mode) ~= ""
end

function M.termcodes(str)
  return api.nvim_replace_termcodes(str, true, true, true)
end

---@return boolean is_git Whether the project is a git project
function M.is_in_git_repo()
  local dir = vim.fn.getcwd()

  while dir ~= "/" do
    if vim.fn.isdirectory(dir .. "/.git") == 1 then
      return true
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end

  return false
end

---@return boolean is_macos Returns true if the operating system is macos
function M.is_macos()
  return vim.loop.os_uname().sysname == "Darwin"
end

---Determine whether dark mode is enabled by the system
---@return boolean is_dark Whether the system is in dark mode
function M.is_dark_mode()
  if M.is_macos() then
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

-- add to the path.
-- This allows for requiring lua modules from that path
---@param path string The path to add
function M.add_path(path)
  package.path = package.path .. ";" .. path
end

---@param servername string The LSP client to check
---@return boolean has_active_lsp_client Whether the provided LSP is enabled
function M.has_active_lsp_client(servername)
  for _, client in pairs(vim.lsp.get_clients()) do
    if client.name == servername then
      return true
    end
  end
  return false
end

---@param t table The table to append to
---@param items table The items to append
function M.table_append(t, items)
  for _, v in ipairs(items) do
    table.insert(t, v)
  end
end

---Check if a directory exists at the provided path
---@param path string The path to check
function M.is_dir(path)
  local stat = vim.loop.fs_stat(path)
  return (stat and stat.type) == "directory"
end

---Check if a value exists in a table
---@param table table The table to check
---@param value any The value to check for
---@return boolean is_in_table Whether the value exists in the table
function M.exists_in_table(table, value)
  for _, v in ipairs(table) do
    if v == value then
      return true
    end
  end
  return false
end

---Load a shared Lua package from a path
---Example: load_shared_lua_package(os.getenv("HOME") .. "/.config/dotfiles")
---@param package_path string
function M.load_shared_lua_package(package_path)
  local paths = {
    package_path .. "/?.lua",
    package_path .. "/?/?.lua",
    package_path .. "/?/init.lua",
  }

  for _, path in ipairs(paths) do
    M.add_path(path)
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

---Create a function that takes a table with a function and its arguments, returning a new function
---@param t table A table where the first element is a function and the rest are its arguments
---@return function A new function that calls the original function with the provided arguments
function M.fun(t)
  local f = t[1]
  local args = { unpack(t, 2) }
  return function()
    return f(unpack(args))
  end
end

---Create a function that takes a function and its arguments, returning a new function
---@param f function The function to call
---@param ... any The arguments to pass to the function
---@return function A new function that calls the original function with the provided arguments
function M.fn(f, ...)
  local args = { ... }
  return function(...)
    return f(unpack(args), ...)
  end
end

return M
