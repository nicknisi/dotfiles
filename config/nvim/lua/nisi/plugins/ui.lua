local config = require("nisi").config
local ascii = require("nisi.assets").ascii
local utils = require("nisi.utils")

local group = vim.api.nvim_create_augroup("Startup", { clear = true })
vim.api.nvim_create_autocmd("FileType", { group = group, pattern = "startup", command = "setlocal list&" })

-- if in a git directory, open git files, otherwise open all files when pressing the "Find File" shortcut
local find_command = utils.is_in_git_repo() and "Telescope git_files" or "Telescope find_files"

return {
  {
    "startup-nvim/startup.nvim",
    opts = {
      header = {
        type = "text",
        align = "center",
        fold_section = false,
        title = "Header",
        content = ascii[config.startup_art],
        highlight = "",
        default_color = config.startup_color,
      },
      body = {
        type = "mapping",
        align = "center",
        fold_section = false,
        title = "Basic Commands",
        margin = 5,
        content = {
          -- TODO can these be made without the mappings?
          { " Find File", find_command, "<leader>t" },
          { " Find Word", "Telescope live_grep", "<leader>fg" },
          { "神 Open Buffers", "Telescope buffers", "<leader>r" },
          { " Recent Files", "Telescope oldfiles", "<leader>fo" },
          { " Open File Drawer", "Neotree reveal toggle", "<leader>k" },
          { " Open Git Index", ":Ge:", ":Ge:" },
          { " New File", ":enew", "e" },
        },
        highlight = "Statement",
      },
      footer = {
        type = "text",
        align = "center",
        fold_section = false,
        title = "Footer",
        margin = 5,
        content = { "https://github.com/nicknisi/dotfiles" },
        highlight = "Number",
        default_color = "",
      },
      colors = { background = "transparent", folded_section = "#56b6c2" },
      mappings = {
        execute_command = "<CR>",
        open_file = "o",
        open_file_split = "<c-o>",
        open_section = "<TAB>",
        open_help = "?",
        quit = "q",
      },
      options = {
        disable_statuslines = true,
        after = function()
          require("startup.utils").oldfiles_mappings()
        end,
      },
      parts = { "header", "body", "footer" },
    },
  },
  -- fast colorizer for showing hex colors
  {
    "NvChad/nvim-colorizer.lua",
    opts = {
      filetypes = { "*" },
      user_default_options = {
        mode = "background",
        tailwind = true,
        RGB = true,
        RRGGBB = true,
        names = true,
        RRGGBBAA = true,
        rgb_fn = true,
        hsl_fn = true,
        css = true,
        css_fn = true,
      },
    },
  },
  -- file drawer plugin
  -- Floating statuslines. This is used to shwo buffer names in splits
  { "b0o/incline.nvim", opts = { hide = { cursorline = false, focused_win = false, only_win = true } } },

  -- Prettier notifications
  {
    "rcarriga/nvim-notify",
    keys = {
      {
        "<leader>un",
        function()
          require("notify").dismiss({ silent = true, pending = true })
        end,
        desc = "Dismiss all Notifications",
      },
    },
    opts = {
      timeout = 3000,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end,
      background_colour = "#1e222a",
      render = "minimal",
    },
    init = function()
      local banned_messages = { "No information available" }
      vim.notify = function(msg, ...)
        for _, banned in ipairs(banned_messages) do
          if msg == banned then
            return
          end
        end
        return require("notify")(msg, ...)
      end
    end,
  },
  { "alvarosevilla95/luatab.nvim", config = true },
  -- improve the default neovim interfaces, such as refactoring
  { "stevearc/dressing.nvim", event = "VeryLazy" },
  { "MunifTanjim/nui.nvim", lazy = true },
  -- Make folds look Prettier
  {
    "kevinhwang91/nvim-ufo",
    dependencies = {
      "kevinhwang91/promise-async",
    },
    opts = {
      fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = ("   %d "):format(endLnum - lnum)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0

        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            local hlGroup = chunk[2]
            table.insert(newVirtText, { chunkText, hlGroup })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            -- str width returned from truncate() may less than 2nd argument, need padding
            if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
            end
            break
          end
          curWidth = curWidth + chunkWidth
        end

        table.insert(newVirtText, { suffix, "MoreMsg" })

        return newVirtText
      end,
      close_fold_kinds_for_ft = { "imports" },
    },
  },
  "RRethy/vim-illuminate", -- highlight the current word
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      -- add any options here
      lsp = {
        -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      -- you can enable a preset for easier configuration
      presets = {
        bottom_search = false, -- use a classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = false, -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = true, -- add a border to hover docs and signature help
      },
      routes = {
        {
          filter = { find = "No information available" },
          opts = { stop = true },
        },
      },
    },
    dependencies = {
      -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
      "MunifTanjim/nui.nvim",
      -- OPTIONAL:
      --   `nvim-notify` is only needed, if you want to use the notification view.
      --   If not available, we use `mini` as the fallback
      "rcarriga/nvim-notify",
    },
  },
}
