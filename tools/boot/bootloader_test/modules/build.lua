#!/usr/libexec/flua

local utils = require('modules.utils')
local parser = require('modules.parser')

local build = { _version = "0.1.0" }

--[[
    -- internal functions --
    -- not part of the contract of this module --
    
    * update_freebsd_img_cache()
    * make_freebsd_minimal_trees()
    * make_freebsd_test_trees()
    * make_freebsd_esps()
    * make_freebsd_images()
    * make_freebsd_scripts()

    -- public functions --
    -- contract of this module --
    build = {
        _version = "0.1.0",
        generate = function(config),
        generate_all_combinations = function(),
    }
    -- config is a table with the following keys:
    -- just enough build tree 
    config = {
        arch = "amd64",
        filesystem = "zfs",
        interface = "gpt",
        encryption = "geli",
        linuxboot_edk2 = "false",
    }

    * build.generate(config)
    * build.generate_all_combinations()
]]--

local function update_freebsd_img_cache()

end

local function make_freebsd_minimal_trees()

end

local function make_freebsd_test_trees()

end

local function make_freebsd_esps()

end

local function make_freebsd_images()

end

local function make_freebsd_scripts()

end


function build.generate(config)
    local arch = config.arch
    local filesystem = config.filesystem
    local interface = config.interface
    local encryption = config.encryption
    local linuxboot_edk2 = config.linuxboot_edk2

    update_freebsd_img_cache()
    make_freebsd_minimal_trees()
    make_freebsd_test_trees()
    make_freebsd_esps()
    make_freebsd_images()
    make_freebsd_scripts()
end

function build.generate_all_combinations(configs)
    for _, config in ipairs(configs) do
        build.generate(config)
    end
end

return build