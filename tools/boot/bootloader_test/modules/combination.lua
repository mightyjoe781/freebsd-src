-- This file is not going to be changed during runtime, instead serves as a
-- resource for the other files. It is not going to be executed directly, but
-- rather imported as a source.

-- package.path = package.path .. ";../modules/?.lua"
local utils = require "modules.utils"

-- list of universe of possible combinations
local combination = {
    arch = {"amd64", "i386", "armv7", "arm64", "riscv64", "powerpc64", "powerpc64le"},
    filesystem = {"zfs", "ufs"},
    interface = {"gpt", "mbr"},
    encryption = {"geli", "none"},
    blacklist_regex = {"riscv64-*-mbr-*"},
    linuxboot_edk2 = {"amd64-*-*-*","arm64-*-*-*"},
    _version = "0.1.0" 
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

-- remove blacklisted-list-regex combinations
function combination.remove_blacklisted_combinations(combinations, blacklist)
    -- remove blacklisted combinations
    local new_combinations = {}
    for _, v in ipairs(combinations) do
        local flag = false
        for _, v2 in ipairs(blacklist) do
            if v:match(v2) then
                flag = true
                break
            end
        end
        if not flag then
            table.insert(new_combinations, v)
        end
    end
    return new_combinations 
end

-- idea here is that generate_combination will generate all possible combinations - blacklisted combinations
-- if user to blacklist more combinations, then we can just remove them from the list similar way
function combination.generate_combinations(regex)
    local combinations = combination.generate_combinations_from_regex(regex)
    -- remove blacklisted combinations
    local blacklist_combination = {}
    for _, v in ipairs(combination.blacklist_regex) do
        -- insert these combinations into blacklist_combination
        local tmp = combination.generate_combinations_from_regex(v)
        for _, v2 in ipairs(tmp) do
            table.insert(blacklist_combination, v2)
        end
    end
    -- remove blacklisted combinations utils.subtract_table
    combinations = utils.subtract_table(combinations, blacklist_combination)
    return combinations
end

-- TODO: Use lua magic to compress below functions into one :P
-- add validation from above list
function combination.is_valid_arch(arch)
    for _, v in ipairs(combination.arch) do
        if v == arch then
            return true
        end
    end
    return false
end

function combination.is_valid_filesystem(filesystem)
    for _, v in ipairs(combination.filesystem) do
        if v == filesystem then
            return true
        end
    end
    return false
end

function combination.is_valid_interface(interface)
    for _, v in ipairs(combination.interface) do
        if v == interface then
            return true
        end
    end
    return false
end

function combination.is_valid_encryption(encryption)
    for _, v in ipairs(combination.encryption) do
        if v == encryption then
            return true
        end
    end
    return false
end


return combination