return {
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        opts = {--[[ things you want to change go here]]
        },
        config = function()
            require("toggleterm").setup {
                size = 25,
                open_mapping = [[<c-\>]],
                direction = "horizontal",
                start_in_insert = true,
            }

            function _G.set_terminal_keymaps()
                if vim.fn.bufname("%"):match("10$") == nil then
                    local opts = { buffer = 0 }
                    vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
                    -- vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
                end
            end

            -- if you only want these mappings for toggle term use term://*toggleterm#* instead
            vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

            -- used for lazygit
            local Terminal = require("toggleterm.terminal").Terminal
            local lazygit = Terminal:new {
                cmd = "lazygit",
                hidden = true,
                direction = "float",
                float_opts = {
                    border = "none",
                    width = 10000,
                    height = 10000,
                },
                count = 10, -- specify the terminal number for keep defalut terminal(0) alive
            }

            function _lazygit_toggle()
                if vim.fn.bufname("%"):match("^term:") == nil then
                    lazygit.dir = vim.fn.expand("%:p:h") -- current working directory for the active buffer
                    lazygit:toggle()
                end
            end

            vim.api.nvim_set_keymap(
                "n",
                "<leader>la",
                "<cmd>lua _lazygit_toggle()<CR>",
                { noremap = true, silent = true }
            )
        end,
    },
}
