local M = {}

M.debug = function(start_line, end_line, count, ...)
    dump(start_line)
    dump(end_line)
    dump(count)
    print("debug")
    local args = ...
    dump(args)
end

M.add = function(start_line, end_line, count, args)
    local cmd_tag = "-add-tags"
    local cmd_option = "-add-options"
    local tags, options = M.get_tags_options(args)
    local cmds = M.make_cmds(cmd_tag, cmd_option, tags, options)

    if count < 0 then
        local byte_offset = M.get_current_byte_offset()
        M.modify(nil, nil, byte_offset, cmds)
    else
        M.modify(start_line, end_line, nil, cmds)
    end
end

M.rm = function(start_line, end_line, count, args)
    local cmd_tag = "-remove-tags"
    local cmd_option = "-remove-options"
    local tags, options = M.get_tags_options(args)
    local cmds = M.make_cmds(cmd_tag, cmd_option, tags, options)

    if count < 0 then
        local byte_offset = M.get_current_byte_offset()
        M.modify(nil, nil, byte_offset, cmds)
    else
        M.modify(start_line, end_line, nil, cmds)
    end
end

M.clear = function()
    local cmd = { "-clear-tags" }
    local byte_offset = M.get_current_byte_offset()
    M.modify(nil, nil, byte_offset, cmd)
end

M.make_cmds = function(cmd_tag, cmd_option, tags, options)
    local cmds = {}
    if #tags == 0 then
        table.insert(tags, "json")
    end

    table.insert(cmds, cmd_tag)
    table.insert(cmds, table.concat(tags, ","))

    if #options > 0 then
        table.insert(cmds, cmd_option)
        table.insert(cmds, table.concat(options, ","))
    end

    return cmds
end

M.get_current_filename = function()
    local fname = vim.fn.expand("%")
    return fname
end

M.split = function(s, delimiter)
    local result = {}
    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return unpack(result)
end

M.get_current_byte_offset = function()
    local fn = vim.fn
    local byte_offset = fn.line2byte(fn.line(".")) + fn.col(".") - 1
    return byte_offset
end

M.modify = function(start_line, end_line, byte_offset, arg)
    local fname = M.get_current_filename()

    local cmds = { "gomodifytags", "-w", "-format", "json", "-file", fname }

    if byte_offset then
        table.insert(cmds, "-offset")
        table.insert(cmds, byte_offset)
    else
        table.insert(cmds, "-line")
        table.insert(cmds, start_line .. "," .. end_line)
    end

    for _, v in ipairs(arg) do
        table.insert(cmds, v)
    end

    -- print(vim.inspect(table.concat(cmds, ' ')))
    vim.fn.jobstart(cmds, {
        on_stderr = function(_, data, _)
            data = M.handle_job_data(data)
            if not data then
                return
            end
            print("ERROR", vim.inspect(data))
        end,
        on_stdout = function(_, data, _)
            data = M.handle_job_data(data)
            if not data then
                return
            end
            local tagged = vim.fn.json_decode(data)
            if tagged.errors ~= nil or tagged.lines == nil or tagged["start"] == nil or tagged["start"] == 0 then
                print("failed to set tags" .. vim.inspect(tagged))
            end
            vim.api.nvim_buf_set_lines(0, tagged["start"] - 1, tagged["start"] - 1 + #tagged.lines, false, tagged.lines)
            print("SUCCESS")
        end,
    })
end

M.get_tags_options = function(args)
    local tags = {}
    local options = {}

    for _, arg in ipairs(args) do
        if arg ~= nil then
            arg = arg:gsub('"', "")
            local tag, option = M.split(arg, ",")

            if tag and tag ~= "" then
                table.insert(tags, tag)
                if option then
                    table.insert(options, tag .. "=" .. option)
                end
            end
        end
    end

    return tags, options
end

M.handle_job_data = function(data)
    if not data then
        return nil
    end
    -- Because the nvim.stdout's data will have an extra empty line
    -- at end on some OS (e.g. maxOS), we should remove it.
    if data[#data] == "" then
        table.remove(data, #data)
    end
    if #data < 1 then
        return nil
    end
    return data
end

vim.cmd([[
    command! -nargs=* -range GoAddTag   call luaeval("require('go.tags').add(_A.line1, _A.line2, _A.count, _A.args)",{'line1':<line1>, 'line2':<line2>, 'count':<count>, 'args':[<f-args>]})
    command! -nargs=* -range GoRmTag    call luaeval("require('go.tags').rm(_A.line1, _A.line2, _A.count, _A.args)",{'line1':<line1>, 'line2':<line2>, 'count':<count>, 'args':[<f-args>]})
    command!                 GoClearTag lua require("go.tags").clear()
]])

return M
