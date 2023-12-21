return {
    {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make"
    },
    {
        "nvim-telescope/telescope.nvim",
        version = "0.1.5",
        dependencies = {
            { "nvim-lua/plenary.nvim" },
            { "nvim-treesitter/nvim-treesitter" },
            { "sharkdp/fd" },
            { "nvim-tree/nvim-web-devicons" },
        },
        config = function()
            local actions = require("telescope.actions")
            local telescope = require("telescope")
            local builtin = require("telescope.builtin")

            vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
            vim.keymap.set(
                "n",
                "<leader>fa",
                "<cmd>Telescope find_files follow=true no_ignore=true hidden=true <CR>",
                {}
            )
            vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
            vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
            vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})
            vim.keymap.set("n", "<leader>fd", builtin.diagnostics, {})
            vim.keymap.set("n", "<leader>fu", builtin.lsp_document_symbols, {})
            vim.keymap.set("n", "<leader>fi", "<cmd>Telescope lsp_dynamic_workspace_symbols path_display=\"hidden\"<cr>", {})
            vim.keymap.set("n", "<leader>fr", builtin.registers, {})
            vim.keymap.set("n", "<leader>fgs", builtin.git_status, {})
            vim.keymap.set("n", "<leader>fo", "<cmd>Telescope oldfiles only_cwd=true<cr>", {})

            telescope.setup {
                defaults = {
                    prompt_prefix = "   ",
                    file_ignore_patterns = {
                        "%.exe",
                        "%.dll",
                        "%.so",
                        "%.o",
                        "%.a",
                        "%.lib",
                        ".git/",
                        "%.zip",
                        "%.rar",
                        "%.tar",
                        "%.gz",
                        "%.pyc",
                        ".cache/",
                    },
                    sorting_strategy = "ascending",
                    layout_strategy = "horizontal",
                    layout_config = {
                        horizontal = {
                            prompt_position = "top",
                            preview_width = 0.55,
                            results_width = 0.8,
                        },
                        vertical = {
                            mirror = false,
                        },
                        width = 0.87,
                        height = 0.80,
                        preview_cutoff = 120,
                    },
                    file_sorter = require("telescope.sorters").get_fuzzy_file,
                    path_display = { "truncate" },
                    winblend = 0,
                    border = {},
                    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
                    mappings = {
                        i = {
                            ["<C-x>"] = actions.file_vsplit,
                            ["<C-j>"] = actions.move_selection_next,
                            ["<C-k>"] = actions.move_selection_previous,
                        },
                    },
                },
                extensions = {
                    fzf = {
                        fuzzy = true, -- false will only do exact matching
                        override_generic_sorter = true, -- override the generic sorter
                        override_file_sorter = true, -- override the file sorter
                        case_mode = "smart_case", -- or "ignore_case" or "respect_case"
                        -- the default case_mode is "smart_case"
                    },
                },
            }
            require("telescope").load_extension("fzf")
        end,
    },
}
