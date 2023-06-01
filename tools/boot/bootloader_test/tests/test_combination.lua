#!/usr/libexec/flua

-- package.path = package.path .. ";../modules/?.lua"
local combination = require('modules.combination')
local luaunit = require('luaunit')

-- Use utils.lua as a library to import functions
function testGenerateRegexFromRegexExpressionArch()
    -- test 1
    local regex = "*-zfs-gpt-geli"
    local res = {}
    for _, arch in ipairs(combination.arch) do
        table.insert(res, arch .. '-zfs-gpt-geli')
    end
    luaunit.assertEquals(combination.generate_combinations_from_simple_regex(regex), res)

    -- test 2
    regex = "amd64-*-gpt-geli"
    res = {}
    for _, filesystem in ipairs(combination.filesystem) do
        table.insert(res, "amd64-" .. filesystem .. "-gpt-geli")
    end
    luaunit.assertEquals(combination.generate_combinations_from_simple_regex(regex), res)

    -- test 3
    regex = "amd64-zfs-*-geli"
    res = {}
    for _, interface in ipairs(combination.interface) do
        table.insert(res, "amd64-zfs-" .. interface .. "-geli")
    end
    luaunit.assertEquals(combination.generate_combinations_from_simple_regex(regex), res)

    -- test 4
    regex = "amd64-zfs-gpt-*"
    res = {}
    for _, encryption in ipairs(combination.encryption) do
        table.insert(res, "amd64-zfs-gpt-" .. encryption)
    end
    luaunit.assertEquals(combination.generate_combinations_from_simple_regex(regex), res)
end


-- -- Use utils.lua as a library to import functions
function testGenerateRegexFromTable()
    local regex_table = {"amd64-*-gpt-geli"}
    local res = {}
    for _, filesystem in ipairs(combination.filesystem) do
        table.insert(res, "amd64-" .. filesystem .. "-gpt-geli")
    end
    luaunit.assertEquals(combination.generate_combinations_from_regex_table(regex_table), res)
end
-- -- Use utils.lua as a library to import functions
function testGenerateRegexFromTable1()
    local regex_table = {"amd64-zfs-gpt-geli"}
    local res = {"amd64-zfs-gpt-geli"}
    luaunit.assertEquals(combination.generate_combinations_from_regex_table(regex_table), res)
end

function testGenerateRegexFromTable2()
    local regex_table = {"amd64-zfs-gpt-geli", "amd64-zfs-gpt-none"}
    local res = {"amd64-zfs-gpt-geli", "amd64-zfs-gpt-none"}
    luaunit.assertEquals(combination.generate_combinations_from_regex_table(regex_table), res)
end
function testGenerateRegexFromTableAll()
    local regex_table = {"*-zfs-gpt-geli", "amd64-*-gpt-geli", "amd64-zfs-*-geli", "amd64-zfs-gpt-*"}
    local res = {
        "amd64-zfs-gpt-geli",
        "i386-zfs-gpt-geli",
        "armv7-zfs-gpt-geli",
        "arm64-zfs-gpt-geli",
        "riscv64-zfs-gpt-geli",
        "powerpc64-zfs-gpt-geli",
        "powerpc64le-zfs-gpt-geli",
        "amd64-ufs-gpt-geli",
        "amd64-zfs-mbr-geli",
        "amd64-zfs-gpt-none"
    }
    luaunit.assertEquals(combination.generate_combinations_from_regex_table(regex_table), res)
end

function testGenerateRegexAllCombinations()
    local regex = "*-*-*-*"
    local res = combination.generate_all_combinations()
    luaunit.assertEquals(combination.generate_combinations_from_regex(regex), res)
end

function testGenerateRegexAllCombinations1()
    local regex = "*-*-*-geli"
    local res = {}
    for _, arch in ipairs(combination.arch) do
        for _, filesystem in ipairs(combination.filesystem) do
            for _, interface in ipairs(combination.interface) do
                table.insert(res, arch .. '-' .. filesystem .. '-' .. interface .. '-geli')
            end
        end
    end
    luaunit.assertEquals(combination.generate_combinations_from_regex(regex), res)
end


os.exit( luaunit.LuaUnit.run() )