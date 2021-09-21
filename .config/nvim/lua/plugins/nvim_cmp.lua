local cmp = require("cmp")
local map = vim.api.nvim_set_keymap

cmp.setup({
    snippet = {
        expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)
        end,
    },

    documentation = {
        border = "rounded",
    },

    preselect = require("cmp.types").cmp.PreselectMode.None,

    -- You must set mapping if you want.
    mapping = {
        ["<C-p>"] = cmp.mapping.select_prev_item(),
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.close(),
        ["<CR>"] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Insert,
            select = true,
        }),
    },

    -- You should specify your *installed* sources.
    sources = {
        { name = "nvim_lsp" },
        { name = "path" },
        { name = "vsnip" },
        { name = "orgmode" },
        { name = "neorg" },
        { name = "nvim_lua" },
        { name = "buffer" },
    },

    formatting = {
        format = function(entry, vim_item)
            -- set a name for each source
            vim_item.menu = ({
                path = "[Path]",
                buffer = "[Buffer]",
                nvim_lsp = "[LSP]",
                luasnip = "[LuaSnip]",
                vsnip = "[VSnip]",
                nvim_lua = "[Lua]",
                latex_symbols = "[Latex]",
                orgmode = "[OrgMode]",
                neorg = "[NeOrg]",
            })[entry.source.name]
            return vim_item
        end,
    },
})

map("i", "<Tab>", [[   vsnip#jumpable(1)  ? '<Plug>(vsnip-jump-next)' : '<Tab>'   ]], { expr = true })
map("s", "<Tab>", [[   vsnip#jumpable(1)  ? '<Plug>(vsnip-jump-next)' : '<Tab>'   ]], { expr = true })
map("i", "<S-Tab>", [[ vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>' ]], { expr = true })
map("s", "<S-Tab>", [[ vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>' ]], { expr = true })
