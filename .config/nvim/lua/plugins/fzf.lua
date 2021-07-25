local o = vim.o
local map = vim.api.nvim_set_keymap
local fn = vim.fn

require('telescope').setup {
    defaults = {
        mappings = {i = {['<esc>'] = require('telescope.actions').close}},
        file_sorter = require'telescope.sorters'.get_fzy_sorter,
        generic_sorter = require'telescope.sorters'.get_fzy_sorter
    }
}

local map_options = {noremap = true, silent = true}

map('n', '<leader>g',
    [[<cmd>lua require('telescope.builtin').find_files({previewer = false})<cr>]],
    map_options)
map('n', '<leader>f',
    [[<cmd>lua require('telescope.builtin').find_files({previewer = false})<cr>]],
    map_options)
map('n', '<leader>r',
    [[<cmd>lua require('telescope.builtin').live_grep({previewer = false})<cr>]],
    map_options)
map('n', '<leader>h',
    [[<cmd>lua require('telescope.builtin').oldfiles({previewer = false})<cr>]],
    map_options)
map('n', '<leader>H',
    [[<cmd>lua require('telescope.builtin').help_tags({previewer = false})<cr>]],
    map_options)

function _G.RgCurrentWord()
    require('telescope.builtin').grep_string {search = vim.fn.expand('<cword>')}
end

map('n', '<leader>R', ':lua RgCurrentWord()<CR>', map_options)

function _G.RgCurrentSelected()
    local _, line_start, column_start, _ = unpack(vim.fn.getpos('\'<'))
    local _, line_end, column_end, _ = unpack(vim.fn.getpos('\'>'))
    local lines = fn.getline(line_start, line_end)
    if #lines == 0 then return '' end
    lines[#lines] = string.sub(lines[#lines], 0, column_end -
                                   (o.selection == 'inclusive' and 0 or 1))
    lines[1] = string.sub(lines[1], column_start)
    local currentSelected = table.concat(lines, '\n')

    require('telescope.builtin').grep_string {search = currentSelected}
end

map('v', '<leader>R', ':lua RgCurrentSelected()<CR>', map_options)
