#!/usr/libexec/flua

-- Use utils.lua as a library to import functions
-- package.path = package.path .. ";../modules/?.lua"
local utils = require('modules.utils')
local luaunit = require('luaunit')

-- Use utils.lua as a library to import functions
function testGenerateRegex()
    luaunit.assertEquals(utils.generate_regex(nil, nil, nil, nil), "*-*-*-*")
    luaunit.assertEquals(utils.generate_regex("amd64", "ufs", nil, "geli"), "amd64-ufs-*-geli")
    luaunit.assertEquals(utils.generate_regex("amd64", nil, "gpt", "geli"), "amd64-*-gpt-geli")
    luaunit.assertEquals(utils.generate_regex("amd64", "ufs", "gpt", "geli"), "amd64-ufs-gpt-geli")
end
os.exit( luaunit.LuaUnit.run() )