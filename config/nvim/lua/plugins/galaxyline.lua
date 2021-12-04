local gl = require("galaxyline")
local gls = gl.section
local theme = require("theme")
local colors = theme.colors
local icons = theme.icons

-- local colors = require("tokyonight.colors").setup()
local condition = require("galaxyline.condition")
local fileinfo = require("galaxyline.provider_fileinfo")
local lsp = require("galaxyline.provider_lsp")
local vcs = require("galaxyline.provider_vcs")

gl.short_line_list = {"NvimTree", "help", "tagbar"}

-- Maps
local mode_color = {
  c = colors.magenta,
  ["!"] = colors.red,
  i = colors.green,
  ic = colors.yellow,
  ix = colors.yellow,
  n = colors.blue,
  no = colors.blue,
  nov = colors.blue,
  noV = colors.blue,
  r = colors.cyan,
  rm = colors.cyan,
  ["r?"] = colors.cyan,
  R = colors.purple,
  Rv = colors.purple,
  s = colors.orange,
  S = colors.orange,
  [""] = colors.orange,
  t = colors.purple,
  v = colors.red,
  V = colors.red,
  [""] = colors.red
}

local mode_icon = {
  c = "🅒 ",
  ["!"] = "🅒 ",
  i = "🅘 ",
  ic = "🅘 ",
  ix = "🅘 ",
  n = "🅝 ",
  R = "🅡 ",
  Rv = "🅡 ",
  r = "🅡 ",
  rm = "🅡 ",
  ["r?"] = "🅡 ",
  s = "🅢 ",
  S = "🅢 ",
  [""] = "🅢 ",
  t = "🅣 ",
  v = "🅥 ",
  V = "🅥 ",
  [""] = "🅥 "
}

-- Left hand side modules
gls.left[0] = {
  Left = {
    highlight = {colors.blue, colors.bg},
    provider = function()
      vim.api.nvim_command("hi GalaxyLeft guifg=" .. mode_color[vim.fn.mode()])
      return "█"
    end
  }
}

gls.left[1] = {
  ModeNum = {
    highlight = {colors.black, colors.bg},
    provider = function()
      vim.api.nvim_command("hi GalaxyModeNum guibg=" .. mode_color[vim.fn.mode()])
      return mode_icon[vim.fn.mode()]
    end
  }
}

gls.left[2] = {
  Left = {
    highlight = {colors.blue, colors.bg},
    provider = function()
      vim.api.nvim_command("hi GalaxyLeft guifg=" .. mode_color[vim.fn.mode()])
      return "█"
    end
  }
}

gls.left[3] = {
  Git = {
    condition = condition.check_git_workspace,
    highlight = {colors.black, colors.bg, "bold"},
    provider = function()
      vim.api.nvim_command("hi GalaxyGit guibg=" .. mode_color[vim.fn.mode()])
      local branch = vcs.get_git_branch()
      if (branch == nil) then
        branch = "???"
      end
      return icons.git .. branch .. " "
    end
  }
}

gls.left[4] = {
  BufSep = {
    highlight = {colors.bg, colors.bg},
    provider = function()
      vim.api.nvim_command("hi GalaxyBufSep guibg=" .. mode_color[vim.fn.mode()])
      return "█"
    end
  }
}

gls.left[5] = {
  FileIcon = {
    condition = condition.buffer_not_empty,
    highlight = {fileinfo.get_file_icon_color, colors.bg},
    provider = "FileIcon"
  }
}

gls.left[6] = {
  FileName = {
    condition = condition.buffer_not_empty,
    highlight = {colors.white, colors.bg, "bold"},
    provider = "FileName"
  }
}

-- Centered modules
gls.mid[0] = {
  Empty = {
    highlight = {colors.bg, colors.bg},
    provider = function()
      return
    end
  }
}

-- Right hand side modules
gls.right[0] = {
  LspClient = {
    highlight = {colors.fg, colors.bg, "bold"},
    provider = function()
      local icon = icons.lsp
      local active_lsp = lsp.get_lsp_client()

      if active_lsp == "No Active Lsp" then
        icon = ""
        active_lsp = ""
      end

      vim.api.nvim_command("hi GalaxyLspClient guifg=" .. mode_color[vim.fn.mode()])
      return icon .. active_lsp .. " "
    end
  }
}

gls.right[1] = {
  DiagnosticError = {
    highlight = {colors.red, colors.bg, "bold"},
    provider = function()
      local count = vim.lsp.diagnostic.get_count(0, "Error")

      if count == 0 then
        return
      else
        return icons.error .. count .. " "
      end
    end
  }
}

gls.right[2] = {
  DiagnosticWarn = {
    highlight = {colors.yellow, colors.bg, "bold"},
    provider = function()
      local count = vim.lsp.diagnostic.get_count(0, "Warning")

      if count == 0 then
        return
      else
        return icons.warning .. count .. " "
      end
    end
  }
}

gls.right[3] = {
  DiagnosticHint = {
    highlight = {colors.cyan, colors.bg, "bold"},
    provider = function()
      local count = vim.lsp.diagnostic.get_count(0, "Hint")

      if count == 0 then
        return
      else
        return icons.hint .. count .. " "
      end
    end
  }
}

gls.right[4] = {
  DiagnosticInfo = {
    highlight = {colors.blue, colors.bg, "bold"},
    provider = function()
      local count = vim.lsp.diagnostic.get_count(0, "Information")

      if count == 0 then
        return
      else
        return icons.info .. count .. " "
      end
    end
  }
}

gls.right[5] = {
  LineSep = {
    highlight = {colors.bg, colors.bg},
    provider = function()
      vim.api.nvim_command("hi GalaxyLineSep guibg=" .. mode_color[vim.fn.mode()])
      return " "
    end
  }
}

gls.right[6] = {
  LineInfo = {
    highlight = {colors.black, colors.bg, "bold"},
    provider = function()
      local cursor = vim.api.nvim_win_get_cursor(0)

      vim.api.nvim_command("hi GalaxyLineInfo guibg=" .. mode_color[vim.fn.mode()])
      return "☰ " .. cursor[1] .. "/" .. vim.api.nvim_buf_line_count(0) .. ":" .. cursor[2]
    end
  }
}

gls.right[7] = {
  Right = {
    highlight = {colors.blue, colors.bg},
    provider = function()
      vim.api.nvim_command("hi GalaxyRight guifg=" .. mode_color[vim.fn.mode()])
      return "█"
    end
  }
}

-- Short line left hand side modules
gls.short_line_left[0] = {
  Left = {
    highlight = {colors.blue, colors.bg},
    provider = function()
      vim.api.nvim_command("hi GalaxyLeft guifg=" .. mode_color[vim.fn.mode()])
      return "█"
    end
  }
}

gls.short_line_left[1] = {
  ModeNum = {
    highlight = {colors.black, colors.bg, "bold"},
    provider = function()
      vim.api.nvim_command("hi GalaxyModeNum guibg=" .. mode_color[vim.fn.mode()])
      return mode_icon[vim.fn.mode()]
    end
  }
}

gls.short_line_left[2] = {
  BufSep = {
    highlight = {colors.bg, colors.bg},
    provider = function()
      vim.api.nvim_command("hi GalaxyBufSep guibg=" .. mode_color[vim.fn.mode()])
      return "█"
    end
  }
}

gls.short_line_left[3] = {
  FileIcon = {
    condition = condition.buffer_not_empty,
    highlight = {fileinfo.get_file_icon_color, colors.bg},
    provider = "FileIcon"
  }
}

gls.short_line_left[4] = {
  FileName = {
    highlight = {colors.white, colors.bg, "bold"},
    provider = "FileName"
  }
}

-- Short line right hand side modules
gls.short_line_right[1] = {
  LineSep = {
    highlight = {colors.bg, colors.bg},
    provider = function()
      vim.api.nvim_command("hi GalaxyLineSep guibg=" .. mode_color[vim.fn.mode()])
      return " "
    end
  }
}

gls.short_line_right[2] = {
  LineInfo = {
    highlight = {colors.black, colors.bg, "bold"},
    provider = function()
      local cursor = vim.api.nvim_win_get_cursor(0)

      vim.api.nvim_command("hi GalaxyLineInfo guibg=" .. mode_color[vim.fn.mode()])
      return "☰ " .. cursor[1] .. "/" .. vim.api.nvim_buf_line_count(0) .. ":" .. cursor[2]
    end
  }
}

gls.short_line_right[3] = {
  Right = {
    highlight = {colors.blue, colors.bg},
    provider = function()
      vim.api.nvim_command("hi GalaxyRight guifg=" .. mode_color[vim.fn.mode()])
      return "█"
    end
  }
}
