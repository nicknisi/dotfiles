return {
    {
        "ellisonleao/glow.nvim",
        keys = {
            { "<leader>gl", "<cmd>Glow<cr>", desc = "Glow" },
        },
        config = function()
            require("glow").setup {
                style = "dark",
                width = 250,
            }
        end,
        cmd = "Glow",
    },
}
