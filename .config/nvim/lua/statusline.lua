local o = vim.o -- global options

local function Dirname()
    if vim.fn.getcwd() == '/' then
        return 'ROOT'
    elseif vim.fn.getcwd() == '$HOME' then
        return 'HOME'
    else
        return vim.fn.toupper(vim.fn.fnamemodify(vim.fn.getcwd(), ':t'))
    end
end

local stl = {Dirname(), ' ', '|', ' %<%f%m%r%h%w', '%=', ' %02v ', '|', ' %l:%c', ' %p%% '}
o.statusline = table.concat(stl)

