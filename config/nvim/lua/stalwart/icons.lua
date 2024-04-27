---@enum (key) NeoIcons
local M = {
  -- system icons
  linux = " ",
  macos = " ",
  windows = " ",
  -- diagnostic icons
  bug = "",
  -- error = "",
  error = " ",
  warning = " ",
  info = " ",
  -- hint = "",
  hint = "󰌶 ",
  lsp = " ",
  -- lsp = " ",
  line = "󰍜 ",
  -- git icons
  git = "",
  conflict = "",
  unstaged = "● ",
  staged = "✓ ",
  unmerged = " ",
  renamed = "➜ ",
  untracked = " ",
  -- deleted = " ",
  ignored = "◌ ",
  modified = "● ",
  deleted = " ",
  added = " ",
  -- file icons
  arrow_closed = " ",
  arrow_open = " ",
  default = " ",
  open = " ",
  empty = " ",
  empty_open = " ",
  -- symlink = "",
  symlink_open = " ",
  file = " ",
  symlink = " ",
  file_readonly = " ",
  file_modified = " ",
  -- misc
  devil = " ",
  bsd = " ",
  ghost = " ",
}

return M
