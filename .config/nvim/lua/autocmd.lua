local vim = vim
local api = vim.api

-- Taken from https://github.com/norcalli/nvim_utils
local function nvim_create_augroups(definitions)
    for group_name, definition in pairs(definitions) do
        api.nvim_command("augroup " .. group_name)
        api.nvim_command("autocmd!")
        for _, def in ipairs(definition) do
            local command = table.concat(vim.tbl_flatten({ "autocmd", def }), " ")
            api.nvim_command(command)
        end
        api.nvim_command("augroup END")
    end
end

local autocmds = {
    back_to_line = {
        {
            "BufReadPost",
            "*",
            [[if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif]],
        },
    },
    vimrc_help = {
        {
            "BufEnter",
            "*.txt",
            [[if &buftype == 'help' | wincmd L | endif]],
        },
    },
}

nvim_create_augroups(autocmds)
