require'compe'.setup {
    enabled = true,
    autocomplete = true,
    debug = false,
    min_length = 1,
    preselect = 'enable',
    throttle_time = 80,
    source_timeout = 200,
    resolve_timeout = 800,
    incomplete_delay = 400,
    max_abbr_width = 100,
    max_kind_width = 100,
    max_menu_width = 100,
    documentation = {
        border = {'', '', '', ' ', '', '', '', ' '}, -- the border option is the same as `|help nvim_open_win|`
        winhighlight = 'NormalFloat:CompeDocumentation,FloatBorder:CompeDocumentationBorder',
        max_width = 120,
        min_width = 60,
        max_height = math.floor(vim.o.lines * 0.3),
        min_height = 1
    },

    source = {
        path = true,
        calc = true,
        buffer = {
            enable = true,
            priority = 1 -- last priority
        },
        nvim_lsp = {
            enable = true,
            priority = 10001 -- takes precedence over file completion
        },
        nvim_lua = true,
        vsnip = true,
        ultisnips = true,
        luasnip = true,
        spell = true
    }
}

local map = vim.api.nvim_set_keymap

map('i', '<C-Space>', 'compe#complete()',
    {noremap = true, silent = true, expr = true})
map('i', '<CR>', 'compe#confirm(\'<CR>\')',
    {noremap = true, silent = true, expr = true})

map('i', '<Tab>',
    [[vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<Tab>']],
    {expr = true})
map('s', '<Tab>',
    [[vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<Tab>']],
    {expr = true})
map('i', '<S-Tab>',
    [[vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>']],
    {expr = true})
map('s', '<S-Tab>',
    [[vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>']],
    {expr = true})
