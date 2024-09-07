local config = require("nisi").config
local icons = require("nisi.assets").icons

return {
  {
    "nvim-lualine/lualine.nvim",
    cond = not vim.g.vscode,
    event = "VeryLazy",
    opts = function(plugin)
      if plugin.override then
        require("lazyvim.util").deprecate("lualine.override", "lualine.opts")
      end

      local diagnostics = {
        "diagnostics",
        sources = { "nvim_diagnostic" },
        sections = { "error", "warn", "info", "hint" },
        symbols = {
          error = icons.bug .. " ",
          hint = icons.hint,
          info = icons.info,
          warn = icons.warning,
        },
        icon = icons.lsp,
        colored = true,
        update_in_insert = false,
        always_visible = false,
      }

      local diff = {
        "diff",
        symbols = {
          added = icons.added,
          untracked = icons.added,
          modified = icons.modified,
          removed = icons.deleted,
        },
        icon = icons.git,
        colored = true,
        always_visible = false,
        source = function()
          local gitsigns = vim.b.gitsigns_status_dict
          if gitsigns then
            return {
              added = gitsigns.added,
              modified = gitsigns.changed,
              removed = gitsigns.removed,
            }
          end
        end,
      }

      return {
        options = {
          theme = "auto",
          icons_enabled = true,
          -- section_separators = { right = "", left = "" },
          -- -- component_separators = "", --{ right = "", left = "" },
          section_separators = { left = "", right = "" },
          -- component_separators = { left = "", right = "" },
          globalstatus = true,
          component_separators = { left = "", right = "" },
          disabled_filetypes = { statusline = { "dashboard", "lazy", "alpha" } },
        },
        sections = config.zen and {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { diff, diagnostics },
          lualine_x = {},
          lualine_y = {},
          lualine_z = {},
        } or {
          lualine_a = {
            { "mode" },
            {
              "macro-recording",
              fmt = function()
                local recording_register = vim.fn.reg_recording()
                if recording_register == "" then
                  return ""
                else
                  return "Recording @" .. recording_register
                end
              end,
            },
          },
          lualine_b = {
            "branch",
            { "diff", symbols = { added = " ", modified = " ", removed = "󰮉 " } },
            "diagnostics",
          },
          lualine_c = { "filename", "searchcount" },
          lualine_x = { "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      }
    end,
    config = function(_, opts)
      local lualine = require("lualine")
      lualine.setup(opts)
      vim.api.nvim_create_autocmd("RecordingEnter", {
        callback = function()
          -- refresh lualine when entering record mode
          lualine.refresh({ place = { "lualine_a" } })
        end,
      })
    end,
  },
}
