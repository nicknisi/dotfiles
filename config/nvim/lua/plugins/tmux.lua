return {
    "aserowy/tmux.nvim",
    dependencies = {
        {
            -- AstroCore is always loaded on startup, so making it a dependency doesn't matter
            "AstroNvim/astrocore",
            opts = {
                mappings = { -- define a mapping to load the plugin module
                    n = {
                        -- navigate windows
                        ["<C-K>"] = false,
                        ["<C-J>"] = false,
                        ["<C-H>"] = false,
                        ["<C-L>"] = false,
                        ["<A-h>"] = {
                            '<cmd>lua require("tmux").move_left()<cr>',
                            desc = "navigate windows including the windows of tmxu",
                        },
                        ["<A-l>"] = {
                            '<cmd>lua require("tmux").move_right()<cr>',
                            desc = "navigate windows including the windows of tmxu",
                        },
                        ["<A-k>"] = {
                            '<cmd>lua require("tmux").move_top()<cr>',
                            desc = "navigate windows including the windows of tmxu",
                        },
                        ["<A-j>"] = {
                            '<cmd>lua require("tmux").move_bottom()<cr>',
                            desc = "navigate windows including the windows of tmxu",
                        },

                        -- resize windows
                        ["<C-Left>"] = false,
                        ["<C-Right>"] = false,
                        ["<C-Up>"] = false,
                        ["<C-Down>"] = false,
                        ["<A-H>"] = { '<cmd>lua require("tmux").resize_left()<cr>', desc = "resize windows" },
                        ["<A-L>"] = { '<cmd>lua require("tmux").resize_right()<cr>', desc = "resize windows" },
                        ["<A-K>"] = { '<cmd>lua require("tmux").resize_top()<cr>', desc = "resize windows" },
                        ["<A-J>"] = { '<cmd>lua require("tmux").resize_bottom()<cr>', desc = "resize windows" },
                    },
                    t = {
                        ["<A-h>"] = {
                            '<cmd>lua require("tmux").move_left()<cr>',
                            desc = "navigate windows including the windows of tmxu",
                        },
                        ["<A-l>"] = {
                            '<cmd>lua require("tmux").move_right()<cr>',
                            desc = "navigate windows including the windows of tmxu",
                        },
                        ["<A-k>"] = {
                            '<cmd>lua require("tmux").move_top()<cr>',
                            desc = "navigate windows including the windows of tmxu",
                        },
                        ["<A-j>"] = {
                            '<cmd>lua require("tmux").move_bottom()<cr>',
                            desc = "navigate windows including the windows of tmxu",
                        },
                    },
                },
            },
        },
    },
    opts = {
        copy_sync = {
            enable = false,
        },
        navigation = {
            cycle_navigation = false,
            enable_default_keybindings = false,
        },
        resize = {
            enable_default_keybindings = false,
            resize_step_x = 3,
            resize_step_y = 3,
        },
    },
}
