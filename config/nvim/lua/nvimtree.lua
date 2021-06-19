vim.api.nvim_set_keymap(
    'n',
    '<leader>k',
    ':NvimTreeToggle<CR>',
    {
        noremap = true,
        silent = true,
    }
)

require('nvim-tree.view').View.width = 40
