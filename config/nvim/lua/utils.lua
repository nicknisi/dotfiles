local api = vim.api
local export = {}

function export.map(mode, combo, mapping, opts)
    local options = { noremap = true, silent = true, expr = false, noremap = false }
    if opts then
        options = vim.tbl_extend('force', options, opts)
    end
    api.nvim_set_keymap(mode, combo, mapping, options)
end

function export.has_module(name)
    if pcall(function() require(name) end) then
        return true
    else
        return false
    end
end


function export.termcodes(str)
  return api.nvim_replace_termcodes(str, true, true, true)
end

return export;
