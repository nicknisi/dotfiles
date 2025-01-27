local utils = require("nisi.utils")
local nmap = utils.nmap
local vmap = utils.vmap
local omap = utils.omap
local xmap = utils.xmap

return {
  {
    "tpope/vim-fugitive",
    lazy = false,
    keys = {
      { "<leader>gr", "<cmd>Gread<cr>", desc = "Read file from git" },
      { "<leader>gb", "<cmd>G blame<cr>", desc = "Read file from git" },
    },
    dependencies = { "tpope/vim-rhubarb" },
  },
  { "akinsho/git-conflict.nvim", version = "*", config = true },
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      on_attach = function(bufnr)
        local gitsigns = require("gitsigns")

        -- Navigation
        nmap("]c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gitsigns.nav_hunk("next")
          end
        end, { desc = "Next hunk" })

        nmap("[c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gitsigns.nav_hunk("prev")
          end
        end, { desc = "Previous hunk" })

        -- Actions
        nmap("<leader>hs", gitsigns.stage_hunk, { desc = "Stage hunk" })
        nmap("<leader>hr", gitsigns.reset_hunk, { desc = "Reset hunk" })
        vmap("<leader>hs", function()
          gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Stage hunk" })
        vmap("<leader>hr", function()
          gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Reset hunk" })
        nmap("<leader>hS", gitsigns.stage_buffer, { desc = "Stage buffer" })
        nmap("<leader>hu", gitsigns.undo_stage_hunk, { desc = "Undo stage hunk" })
        nmap("<leader>hR", gitsigns.reset_buffer, { desc = "Reset buffer" })
        nmap("<leader>hp", gitsigns.preview_hunk, { desc = "Preview hunk" })
        nmap("<leader>hb", function()
          gitsigns.blame_line({ full = true })
        end, { desc = "Blame line" })
        nmap("<leader>tb", gitsigns.toggle_current_line_blame, { desc = "Toggle current line blame" })
        nmap("<leader>hd", gitsigns.diffthis, { desc = "Diff this" })
        nmap("<leader>hD", function()
          gitsigns.diffthis("~")
        end, { desc = "Diff this file" })
        nmap("<leader>td", gitsigns.toggle_deleted, { desc = "Toggle deleted" })

        -- Text object
        omap("ih", ":<C-U>Gitsigns select_hunk<CR>")
        xmap("ih", ":<C-U>Gitsigns select_hunk<CR>")
      end,
    },
  },
}
