return{
    "nvim-lualine/lualine.nvim",
    config = function()
        require('lualine').setup{
            extensions = {"nvim-tree"}
        }
    end
}
