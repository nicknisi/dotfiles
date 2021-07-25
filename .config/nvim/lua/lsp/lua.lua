USER = vim.fn.expand('$USER')

local sumneko_root_path = '/Users/' .. USER .. '/.config/lua-language-server'
local sumneko_binary = '/Users/' .. USER ..
                           '/.config/lua-language-server/bin/macOS/lua-language-server'

local library = {}

-- this is the ONLY correct way to setup your path
local path = vim.split(package.path, ';')
table.insert(path, 'lua/?.lua')
table.insert(path, 'lua/?/init.lua')

local function add(lib)
    for _, p in pairs(vim.fn.expand(lib, false, true)) do
        p = vim.loop.fs_realpath(p)
        library[p] = true
    end
end

-- add runtime
add('$VIMRUNTIME/lua')
add('$VIMRUNTIME/lua/vim/lsp')

-- add your config
add('~/.config/nvim')

-- add plugins
--[[ add("~/.local/share/nvim/site/pack/packer/opt/*")
add("~/.local/share/nvim/site/pack/packer/start/*") ]]

require('lspconfig').sumneko_lua.setup {
    on_attach = require('lsp.attach').on_attach,
    cmd = {sumneko_binary, '-E', sumneko_root_path .. '/main.lua'},
    settings = {
        Lua = {
            runtime = {
                -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                version = 'LuaJIT',
                -- Setup your lua path
                path = path
            },
            diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = {'vim'}
            },
            workspace = {
                -- Make the server aware of Neovim runtime files
                library = library
            },
            -- Do not send telemetry data containing a randomized but unique identifier
            telemetry = {enable = false}
        }
    }
}
