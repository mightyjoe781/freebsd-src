#!/usr/libexec/flua

-- Use utils.lua as a library to import functions

local utils = { _version = "0.1.0" }

-- generate regex from args
function utils.generate_regex(arch, filesystem, interface, encryption)
    -- any of the args is not passed, use '*' for that arg
    if arch == nil then
        arch = '*'
    end
    if filesystem == nil then
        filesystem = '*'
    end
    if interface == nil then
        interface = '*'
    end
    if encryption == nil then
        encryption = '*'
    end
    return arch .. '-' .. filesystem .. '-' .. interface .. '-' .. encryption
end

-- remove duplicates from a table
function utils.remove_duplicates(t)
    local hash = {}
    local res = {}
    for _, v in ipairs(t) do
        if not hash[v] then
            res[#res+1] = v
            hash[v] = true
        end
    end
    return res
end

-- load a data file
function utils.load_data_file(file)
    local f = io.open(file, "rb")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

return utils