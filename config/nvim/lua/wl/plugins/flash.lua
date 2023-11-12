return {
    {
        "folke/flash.nvim",
        event = "VeryLazy",
        opts = {
            modes = {
                search = {
                    enabled = true,
                    highlight = { backdrop = true },
                },
                char = {
                    jump_labels = true,
                },
            },
            label = {
                uppercase = false,
            },
        },
        keys = {
            -- {
            --     "s",
            --     mode = { "n", "x", "o" },
            --     function()
            --         require("flash").jump()
            --     end,
            --     desc = "Flash",
            -- },
            {
                "S",
                mode = { "n", "o", "x" },
                function()
                    require("flash").treesitter()
                end,
                desc = "Flash Treesitter",
            },
            {
                "<c-s>",
                mode = { "c" },
                function()
                    require("flash").toggle()
                end,
                desc = "Toggle Flash Search",
            },
            -- { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
            -- { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
        },
    },
}
