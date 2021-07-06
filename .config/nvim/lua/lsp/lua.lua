USER = vim.fn.expand('$USER')

local sumneko_root_path = "/Users/" .. USER .. "/.config/lua-language-server"
local sumneko_binary = "/Users/" .. USER .. "/.config/lua-language-server/bin/macOS/lua-language-server"

local library = {}

local path = vim.split(package.path, ";")

-- this is the ONLY correct way to setup your path
table.insert(path, "lua/?.lua")
table.insert(path, "lua/?/init.lua")

local function add(lib)
    for _, p in pairs(vim.fn.expand(lib, false, true)) do
        p = vim.loop.fs_realpath(p)
        library[p] = true
    end
end

-- add runtime
add("$VIMRUNTIME")

-- add your config
add("~/.config/nvim")

-- add plugins
add("~/.local/share/nvim/site/pack/paqs/opt/*")
add("~/.local/share/nvim/site/pack/paqs/start/*")

require('lspconfig').sumneko_lua.setup {
    on_attach = require('lsp/attach').on_attach,
    cmd = {sumneko_binary, "-E", sumneko_root_path .. "/main.lua"},
    settings = {
        Lua = {
            runtime = {
                -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                version = 'LuaJIT',
                -- Setup your lua path
                -- path = vim.split(package.path, ';')
                path = path
            },
            diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = {'vim'}
            },
            workspace = {
                -- Make the server aware of Neovim runtime files
                -- library = {[vim.fn.expand('$VIMRUNTIME/lua')] = true, [vim.fn.expand('$VIMRUNTIME/lua/vim/lsp')] = true}
                library = library,
                maxPreload = 2000,
                preloadFileSize = 5000
            },
            -- Do not send telemetry data containing a randomized but unique identifier
            telemetry = {enable = false}
        }
    }
}
