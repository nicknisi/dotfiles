local api = vim.api
---@class NeoUtils
local M = {}

-- thanks to
-- https://github.com/akinsho/dotfiles/blob/main/.config/nvim/lua/as/globals.lua
-- for inspiration
local function make_keymap_fn(mode, o)
  -- copy the opts table as extends will mutate opts
  local parent_opts = vim.deepcopy(o)
  return function(combo, mapping, opts)
    assert(combo ~= mode, string.format("The combo should not be the same as the mode for %s", combo))
    local _opts = opts and vim.deepcopy(opts) or {}

    if type(mapping) == "function" then
      local fn_id = globals._create(mapping)
      mapping = string.format("<cmd>lua globals._execute(%s)<cr>", fn_id)
    end

    if _opts.bufnr then
      local bufnr = _opts.bufnr
      _opts.bufnr = nil
      _opts = vim.tbl_extend("keep", _opts, parent_opts)
      api.nvim_buf_set_keymap(bufnr, mode, combo, mapping, _opts)
    else
      api.nvim_set_keymap(mode, combo, mapping, vim.tbl_extend("keep", _opts, parent_opts))
    end
  end
end

local map_opts = { noremap = false, silent = true }
M.nmap = make_keymap_fn("n", map_opts)
M.xmap = make_keymap_fn("x", map_opts)
M.imap = make_keymap_fn("i", map_opts)
M.vmap = make_keymap_fn("v", map_opts)
M.omap = make_keymap_fn("o", map_opts)
M.tmap = make_keymap_fn("t", map_opts)
M.smap = make_keymap_fn("s", map_opts)
M.cmap = make_keymap_fn("c", map_opts)

local noremap_opts = { noremap = true, silent = true }
M.nnoremap = make_keymap_fn("n", noremap_opts)
M.xnoremap = make_keymap_fn("x", noremap_opts)
M.vnoremap = make_keymap_fn("v", noremap_opts)
M.inoremap = make_keymap_fn("i", noremap_opts)
M.onoremap = make_keymap_fn("o", noremap_opts)
M.tnoremap = make_keymap_fn("t", noremap_opts)
M.cnoremap = make_keymap_fn("c", noremap_opts)

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
  for _, client in pairs(vim.lsp.get_active_clients()) do
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

return M
