-- This file is not going to be changed during runtime, instead serves as a
-- resource for the other files. It is not going to be executed directly, but
-- rather imported as a source.

local combination = { _version = "0.1.0" }
-- package.path = package.path .. ";../modules/?.lua"
local utils = require "modules.utils"

-- list of universe of possible combinations
combination = {
    arch = {"amd64", "i386", "armv7", "arm64", "riscv64", "powerpc64", "powerpc64le"},
    filesystem = {"zfs", "ufs"},
    interface = {"gpt", "mbr"},
    encryption = {"geli", "none"},
}


-- generate all possible combinations
function combination.generate_all_combinations()
    local combinations = {}
    for _, arch in ipairs(combination.arch) do
        for _, filesystem in ipairs(combination.filesystem) do
            for _, interface in ipairs(combination.interface) do
                for _, encryption in ipairs(combination.encryption) do
                    table.insert(combinations, arch .. '-' .. filesystem .. '-' .. interface .. '-' .. encryption)
                end
            end
        end
    end
    return combinations
end


-- generate possible combination from regex string arch-filesystem-interface-encryption
-- simple regex contains only one wildcard
function combination.generate_combinations_from_simple_regex(regex)
    local combinations = {}
    local arch, filesystem, interface, encryption = regex:match("([^,]+)-([^,]+)-([^,]+)-([^,]+)")
    if arch == "*" then
        for _, arch in ipairs(combination.arch) do
            table.insert(combinations, arch .. '-' .. filesystem .. '-' .. interface .. '-' .. encryption)
        end
    end
    if filesystem == "*" then
        for _, filesystem in ipairs(combination.filesystem) do
            table.insert(combinations, arch .. '-' .. filesystem .. '-' .. interface .. '-' .. encryption)
        end
    end
    if interface == "*" then
        for _, interface in ipairs(combination.interface) do
            table.insert(combinations, arch .. '-' .. filesystem .. '-' .. interface .. '-' .. encryption)
        end
    end
    if encryption == "*" then
        for _, encryption in ipairs(combination.encryption) do
            table.insert(combinations, arch .. '-' .. filesystem .. '-' .. interface .. '-' .. encryption)
        end
    end
    -- if no wildcard, return the original regex
    if arch ~= "*" and filesystem ~= "*" and interface ~= "*" and encryption ~= "*" then
        table.insert(combinations, regex)
    end
    return combinations
end

function combination.generate_combinations_from_regex_table(t) 
    -- returns new table with one less level of wildcard
    -- assumes wildcards are present
    local new_t = {}
    for _, v in ipairs(t) do
        local tmp = combination.generate_combinations_from_simple_regex(v)
        for _, v2 in ipairs(tmp) do
            table.insert(new_t, v2)
        end
    end
    new_t = utils.remove_duplicates(new_t)
    return new_t
end

-- this function perfectly parses wildcard regex and returns all unique possible combinations
function combination.generate_combinations_from_regex(regex)
    local combinations = {}
    local arch, filesystem, interface, encryption = regex:match("([^,]+)-([^,]+)-([^,]+)-([^,]+)")

    -- count number of wildcard
    local count = 0
    count = count + (arch == "*" and 1 or 0) + (filesystem == "*" and 1 or 0) + (interface == "*" and 1 or 0) + (encryption == "*" and 1 or 0)
    -- if no wildcard, return the original regex
    if count == 0 then
        table.insert(combinations, regex)
        return combinations
    end

    -- zero or one wildcard, return the combinations from simple regex
    combinations = combination.generate_combinations_from_simple_regex(regex)
    -- if more than one wildcard, return the combinations from table of simple regex
    if count > 1 then
        local t = combinations
        for i = 1, count - 1 do
            t = combination.generate_combinations_from_regex_table(t)
        end
        combinations = t
    end
    return combinations

end

return combination