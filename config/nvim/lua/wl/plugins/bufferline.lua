return {
    {
        'akinsho/bufferline.nvim',
        version = "v3.*",
        dependencies = 'nvim-tree/nvim-web-devicons',
        config = function()
            vim.opt.termguicolors = true
            require("bufferline").setup{
                options = {
                    numbers = "buffer_id",
                    indicator = {
                        icon = '▎',
                        style = "underline"
                    },
                    separator_style = {"▎", "▎"},
                    offsets = {
                    {
                        filetype = "NvimTree",
                        text = "File Explorer",
                        text_align = "left",
                        separator = true
                    }
            }
                },
            }
        end
    }
}
