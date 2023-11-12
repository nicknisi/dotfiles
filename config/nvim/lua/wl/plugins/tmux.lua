return {
    "aserowy/tmux.nvim",
    config = function()
        require("tmux").setup {
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
        }

        local opts = { noremap = true, silent = true }
        vim.keymap.set("n", "<A-h>", ":lua require(\"tmux\").move_left()<cr>", opts)
        vim.keymap.set("n", "<A-l>", ":lua require(\"tmux\").move_right()<cr>", opts)
        vim.keymap.set("n", "<A-k>", ":lua require(\"tmux\").move_top()<cr>", opts)
        vim.keymap.set("n", "<A-j>", ":lua require(\"tmux\").move_bottom()<cr>", opts)

        vim.keymap.set("n", "<A-H>", ":lua require(\"tmux\").resize_left()<cr>", opts)
        vim.keymap.set("n", "<A-L>", ":lua require(\"tmux\").resize_right()<cr>", opts)
        vim.keymap.set("n", "<A-K>", ":lua require(\"tmux\").resize_top()<cr>", opts)
        vim.keymap.set("n", "<A-J>", ":lua require(\"tmux\").resize_bottom()<cr>", opts)
    end,
}
