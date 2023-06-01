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

return utils