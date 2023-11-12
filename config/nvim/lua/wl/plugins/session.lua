return {
    {
        "rmagatti/auto-session",
        config = function()
            require("auto-session").setup {
                log_level = "error",
                auto_session_suppress_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
            }
        end,
    },
    {
        -- used to load in telescope
        "rmagatti/session-lens",
        dependencies = { "rmagatti/auto-session", "nvim-telescope/telescope.nvim" },
        config = function()
            require("session-lens").setup {--[[your custom config--]]
            }
            require("telescope").load_extension("session-lens")
        end,
    },
}
