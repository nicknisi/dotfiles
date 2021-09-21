if not pcall(require, "telescope") then
    return
end

local map = vim.api.nvim_set_keymap
local actions = require("telescope.actions")
local sorters = require("telescope.sorters")
local map_options = { noremap = true, silent = true }
local M = {}

require("telescope").setup({
    defaults = {
        prompt_prefix = "❯ ",
        selection_caret = "❯ ",
        selection_strategy = "reset",
        sorting_strategy = "ascending",
        scroll_strategy = "cycle",
        color_devicons = true,
        winblend = 0,

        mappings = {
            i = {
                ["<C-s>"] = actions.select_horizontal,
                ["<C-v>"] = actions.select_vertical,
                ["<C-t>"] = actions.select_tab,

                ["<C-j>"] = actions.move_selection_next,
                ["<C-k>"] = actions.move_selection_previous,

                ["<C-c>"] = actions.close,
                ["<esc>"] = actions.close,
            },
        },

        borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },

        file_sorter = sorters.get_fzy_sorter,
        generic_sorter = sorters.get_fzy_sorter,
        file_ignore_patterns = { "node_modules", ".pyc" },

        file_previewer = require("telescope.previewers").vim_buffer_cat.new,
        grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
        qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,

        vimgrep_arguments = {
            "rg",
            "--hidden",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
        },
    },

    extensions = {
        fzy_native = {
            override_generic_sorter = true,
            override_file_sorter = true,
        },

        fzf_writer = { use_highlighter = false, minimum_grep_characters = 6 },

        frecency = { workspaces = { ["conf"] = "~/.config/nvim/" } },
    },
})

require("telescope").load_extension("fzy_native")

M.grep_cword = function()
    require("telescope.builtin").grep_string({
        previewer = false,
        search = vim.fn.expand("<cword>"),
    })
end

M.grep_visual = function()
    local _, csrow, cscol, cerow, cecol
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "" then
        -- if we are in visual mode use the live position
        _, csrow, cscol, _ = unpack(vim.fn.getpos("."))
        _, cerow, cecol, _ = unpack(vim.fn.getpos("v"))
        if mode == "V" then
            -- visual line doesn't provide columns
            cscol, cecol = 0, 999
        end
        -- exit visual mode
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
    else
        -- otherwise, use the last known visual position
        _, csrow, cscol, _ = unpack(vim.fn.getpos("'<"))
        _, cerow, cecol, _ = unpack(vim.fn.getpos("'>"))
    end
    -- swap vars if needed
    if cerow < csrow then
        csrow, cerow = cerow, csrow
    end
    if cecol < cscol then
        cscol, cecol = cecol, cscol
    end
    local lines = vim.fn.getline(csrow, cerow)
    local n = #lines
    if n <= 0 then
        return ""
    end
    lines[n] = string.sub(lines[n], 1, cecol)
    lines[1] = string.sub(lines[1], cscol)

    dump(csrow, cscol, cerow, cecol, lines)

    require("telescope.builtin").grep_string({
        previewer = false,
        search = table.concat(lines, "\n"),
    })
end

map("n", "<leader>g", [[<cmd>lua require('telescope.builtin').find_files({previewer = false})<cr>]], map_options)
map("n", "<leader>r", [[<cmd>lua require('telescope.builtin').live_grep({previewer = false})<cr>]], map_options)
map("n", "<leader>h", [[<cmd>lua require('telescope.builtin').help_tags({previewer = false})<cr>]], map_options)
map("n", "<leader>m", [[<cmd>lua require('telescope.builtin').keymaps()<cr>]], map_options)
map("n", "<leader>b", [[<cmd>lua require('telescope.builtin').builtin()<cr>]], map_options)

map("n", "<leader>R", [[<cmd>lua require('plugins.telescope').grep_cword()<cr>]], map_options)
map("v", "<leader>R", [[<cmd>lua require('plugins.telescope').grep_visual()<cr>]], map_options)

return M
