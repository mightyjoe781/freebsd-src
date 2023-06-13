#!/usr/libexec/flua

local utils = require('modules.utils')
local posix = require('posix')
local parser = require('modules.parser')
local zfs = require('modules.zfs')
local ufs = require('modules.ufs')

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

-- constants
local ARCH = {"amd64:amd64", "i386:i386", "arm64:aarch64", "arm:armv7", "powerpc:powerpc", "powerpc64:powerpc64", "riscv64:riscv64", "powerpc64le:powerpc64le"}
local URLBASE = "https://download.freebsd.org/ftp/releases"

-- find the machine architecure from the arch string
local function get_machine_arch(arch)
    -- find the machine architecture from the arch string

end

-- find flavour from the arch string
local function find_flavour(arch)
    local machine, _ = string.match(ARCH[arch], "(%w+):(%w+)")
    local flavour
    -- for arm64, we have GENERICSD images only
    if machine == "arm64" then
      flavour = "GENERICSD"
    else
      -- else download bootonly.iso images
      flavour = "bootonly.iso"
    end
    return flavour
end

-- download freebsd image using curl
local function download_freebsd_img(arch, flavour)
    local machine, machine_arch = string.match(ARCH[arch], "(%w+):(%w+)")
    local machine_combo = machine_combo(machine, machine_arch)
    local file="FreeBSD-"..FREEBSD_VERSION.."-RELEASE-"..machine_combo.."-"..flavour
    local url = URLBASE.."/"..machine.."/"..machine_arch.."/ISO-IMAGES/"..FREEBSD_VERSION.."/"..file..".xz"

    -- make sure CACHE_DIR exists
    execute("mkdir -p "..CACHE_DIR)

    if utils.file_exists(CACHE_DIR.."/"..file) then
        return
    end

    -- else download file using fetch from freebsd or die
    execute("fetch -o "..CACHE_DIR.."/"..file..".xz "..url)
    -- uncompress the file or die
    execute("xz -d "..CACHE_DIR.."/"..file..".xz")
end


-- update freebsd img cache
local function update_freebsd_img_cache(arch)
    -- download freebsd image cache for all supported architectures
    local arch, machine_arch = get(arch)
    local flavour = find_flavour(arch)
    download_freebsd_img(arch, flavour)
end


local function update_freebsd_img_cache(arch)
    -- find flavour for the arch
    local flavour = find_flavour(arch)

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

    local machine = config.arch
    local machine_arch = get_machine_arch(machine)
    local flavour = get_flavour(arch)
    local filesystem = config.filesystem
    local interface = config.interface
    local encryption = config.encryption
    local linuxboot_edk2 = config.linuxboot_edk2

    update_freebsd_img_cache(arch, flavour)
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