local colors = {
  bg = "#202328",
  fg = "#bbc2cf",
  aqua = "#3affdb",
  beige = "#f5c06f",
  blue = "#51afef",
  brown = "#905532",
  cyan = "#008080",
  darkblue = "#081633",
  darkorange = "#f16529",
  green = "#98be65",
  grey = "#8c979a",
  lightblue = "#5fd7ff",
  lightgreen = "#31b53e",
  magenta = "#c678dd",
  orange = "#d4843e",
  pink = "#cb6f6f",
  purple = "#834f79",
  red = "#ae403f",
  salmon = "#ee6e73",
  violet = "#a9a1e1",
  white = "#eff0f1",
  yellow = "#f09f17",
  black = "#202328",
}

local icons = {
  -- system icons
  linux = " ",
  macos = " ",
  windows = " ",
  -- diagnostic icons
  -- error = "",
  -- error = "",
  error = " ",
  warning = " ",
  info = " ",
  -- hint = "",
  hint = "󰌶 ",
  -- lsp = " ",
  lsp = " ",
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

local border = {
  { "🭽", "FloatBorder" },
  { "▔", "FloatBorder" },
  { "🭾", "FloatBorder" },
  { "▕", "FloatBorder" },
  { "🭿", "FloatBorder" },
  { "▁", "FloatBorder" },
  { "🭼", "FloatBorder" },
  { "▏", "FloatBorder" },
}

local function get_current_theme()
  local file = io.open(os.getenv("HOME") .. "/.theme", "r")

  if not file then
    return "catppuccin"
  end

  local content = file:read("*a")
  file:close()

  content = content:gsub("%s+", "")

  return content
end

return { colors = colors, icons = icons, border = border, get_current_theme = get_current_theme }
