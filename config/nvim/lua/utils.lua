local api = vim.api
local export = {}

function export.map(mode, combo, mapping, opts)
    local options = { noremap = true, silent = true, expr = false }
    if opts then
        options = vim.tbl_extend('force', options, opts)
    end
    api.nvim_set_keymap(mode, combo, mapping, options)
end

return export;
