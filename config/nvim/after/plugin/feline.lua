local theme = require("theme")
local colors = theme.colors
local icons = theme.icons

local vi_mode_colors = {
  NORMAL = colors.violet,
  INSERT = colors.aqua,
  VISUAL = colors.magenta,
  OP = colors.green,
  BLOCK = colors.blue,
  REPLACE = colors.violet,
  ["V-REPLACE"] = colors.darkorange,
  ENTER = colors.cyan,
  MORE = colors.cyan,
  SELECT = colors.orange,
  COMMAND = colors.green,
  SHELL = colors.green,
  TERM = colors.green,
  NONE = colors.yellow
}

local function file_osinfo()
  local os = vim.bo.fileformat:upper()
  local icon
  if os == "UNIX" then
    icon = icons.linux
  elseif os == "MAC" then
    icon = icons.macos
  else
    icon = icons.windows
  end
  return icon .. os
end

local lsp = require "feline.providers.lsp"
local vi_mode_utils = require "feline.providers.vi_mode"

local lsp_get_diag = function(str)
  local diagnostics = vim.diagnostic.get(0, {severity = str})
  local count = #diagnostics
  return (count > 0) and " " .. count .. " " or ""
end

local comps = {
  vi_mode = {
    left = {
      provider = function()
        return " " .. icons.ghost .. " " .. vi_mode_utils.get_vim_mode()
      end,
      hl = function()
        local val = {
          name = vi_mode_utils.get_mode_highlight_name(),
          fg = vi_mode_utils.get_mode_color()
          -- fg = colors.bg
        }
        return val
      end,
      right_sep = " "
    },
    right = {
      -- provider = '▊',
      provider = "",
      hl = function()
        local val = {
          name = vi_mode_utils.get_mode_highlight_name(),
          fg = vi_mode_utils.get_mode_color()
        }
        return val
      end,
      left_sep = " ",
      right_sep = " "
    }
  },
  file = {
    info = {
      provider = {
        name = "file_info",
        opts = {
          type = "relative-short",
          file_readonly_icon = icons.file_readonly,
          file_modified_icon = icons.file_modified
        }
      },
      hl = {
        fg = colors.blue,
        style = "bold"
      }
    },
    encoding = {
      provider = "file_encoding",
      left_sep = " ",
      hl = {
        fg = colors.violet,
        style = "bold"
      }
    },
    type = {
      provider = "file_type"
    },
    os = {
      provider = file_osinfo,
      left_sep = " ",
      hl = {
        fg = colors.violet,
        style = "bold"
      }
    },
    position = {
      provider = "position",
      left_sep = " ",
      hl = {
        fg = colors.cyan
        -- style = 'bold'
      }
    }
  },
  left_end = {
    provider = function()
      return ""
    end,
    hl = {
      fg = colors.bg,
      bg = colors.blue
    }
  },
  line_percentage = {
    provider = "line_percentage",
    left_sep = " ",
    hl = {
      style = "bold"
    }
  },
  scroll_bar = {
    provider = "scroll_bar",
    left_sep = " ",
    hl = {
      fg = colors.blue,
      style = "bold"
    }
  },
  diagnos = {
    err = {
      -- provider = 'diagnostic_errors',
      provider = function()
        return icons.error .. lsp_get_diag("Error")
      end,
      -- left_sep = ' ',
      enabled = function()
        return lsp.diagnostics_exist("Error")
      end,
      hl = {
        fg = colors.red
      }
    },
    warn = {
      provider = function()
        return icons.warning .. lsp_get_diag("Warn")
      end,
      enabled = function()
        return lsp.diagnostics_exist("Warn")
      end,
      hl = {
        fg = colors.yellow
      }
    },
    info = {
      provider = function()
        return icons.info .. lsp_get_diag("Info")
      end,
      enabled = function()
        return lsp.diagnostics_exist("Info")
      end,
      hl = {
        fg = colors.blue
      }
    },
    hint = {
      provider = function()
        return icons.hint .. lsp_get_diag("Hint")
      end,
      enabled = function()
        return lsp.diagnostics_exist("Hint")
      end,
      hl = {
        fg = colors.cyan
      }
    }
  },
  lsp = {
    name = {
      provider = "lsp_client_names",
      left_sep = " ",
      icon = icons.lsp .. " ",
      right_sep = " ",
      hl = {
        fg = colors.grey
      }
    }
  },
  git = {
    branch = {
      provider = "git_branch",
      right_sep = " ",
      icon = icons.git .. " ",
      left_sep = " ",
      hl = {
        fg = colors.violet,
        style = "bold"
      }
    },
    add = {
      provider = "git_diff_added",
      hl = {
        fg = colors.green
      }
    },
    change = {
      provider = "git_diff_changed",
      icon = " " .. icons.modified .. " ",
      hl = {
        fg = colors.orange
      }
    },
    remove = {
      provider = "git_diff_removed",
      hl = {
        fg = colors.red
      }
    }
  }
}

local components = {
  active = {},
  inactive = {}
}

table.insert(components.active, {})
table.insert(components.active, {})
table.insert(components.active, {})
table.insert(components.inactive, {})
table.insert(components.inactive, {})
table.insert(components.inactive, {})

table.insert(components.active[1], comps.vi_mode.left)
table.insert(components.active[1], comps.file.info)
table.insert(components.active[1], comps.git.branch)
table.insert(components.active[1], comps.git.add)
table.insert(components.active[1], comps.git.change)
table.insert(components.active[1], comps.git.remove)
table.insert(components.inactive[1], comps.vi_mode.left)
table.insert(components.inactive[1], comps.file.info)
table.insert(components.active[3], comps.diagnos.err)
table.insert(components.active[3], comps.diagnos.warn)
table.insert(components.active[3], comps.diagnos.hint)
table.insert(components.active[3], comps.diagnos.info)
table.insert(components.active[3], comps.lsp.name)
table.insert(components.active[3], comps.file.os)
table.insert(components.active[3], comps.file.position)
table.insert(components.active[3], comps.line_percentage)
table.insert(components.active[3], comps.scroll_bar)
table.insert(components.active[3], comps.vi_mode.right)

require("feline").setup(
  {
    theme = {
      bg = colors.bg,
      fg = colors.fg
    },
    components = components,
    vi_mode_colors = vi_mode_colors,
    force_inactive = {
      filetypes = {
        "packer",
        "NvimTree",
        "fugitive",
        "fugitiveblame"
      },
      buftypes = {"terminal"},
      bufnames = {}
    }
  }
)
