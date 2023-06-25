#!/usr/libexec/flua

--------------------------------------------------------------------------------
--                                import modules
--------------------------------------------------------------------------------
local utils = require('modules.utils')
local posix = require('posix')
local parser = require('modules.parser')
local zfs = require('modules.zfs')
local ufs = require('modules.ufs')


--------------------------------------------------------------------------------
--                                constants
--------------------------------------------------------------------------------
local HOME = os.getenv("HOME")
local QEMU_BIN = "/usr/local/bin/qemu-system-x86_64"

local STAND_ROOT = HOME.."/stand-test-root"
local BIOS_DIR = STAND_ROOT.."/bios"
local CACHE_DIR = STAND_ROOT.."/cache"
local IMAGE_DIR = STAND_ROOT.."/images"
local OVERRIDES = STAND_ROOT.."/overrides"
local SCRIPT_DIR = STAND_ROOT.."/scripts"
local TREE_DIR = STAND_ROOT.."/trees"

local build = {
    -- use ../sources/ as the default directory for building freebsd trees
    CACHE_DIR = STAND_ROOT.."/cache",
    IMAGE_DIR = STAND_ROOT.."/images",
    BIOS_DIR = STAND_ROOT.."/bios",
    SCRIPT_DIR = STAND_ROOT.."/scripts",
    TREE_DIR = STAND_ROOT.."/trees",
    OVERRIDES = STAND_ROOT.."/overrides",
    FREEBSD_VERSION = "13.1",
    URLBASE = "https://download.freebsd.org/ftp/releases",

    _version = "0.1.0" 
}
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
--                               internal functions
--------------------------------------------------------------------------------

-- constants
local ARCH = {"amd64:amd64", "i386:i386", "arm64:aarch64", "arm:armv7", "powerpc:powerpc", "powerpc64:powerpc64", "riscv64:riscv64", "powerpc64le:powerpc64le"}

-- find the machine architecure from machine
local function get_machine_arch(arch)
    for _, arch_string in ipairs(ARCH) do
        local machine, machine_arch = string.match(arch_string, "(%w+):(%w+)")
        if machine == arch then
            return machine_arch
        end
    end
    return nil
end

local function get_machine_combo(machine, machine_arch)
    if machine ~= machine_arch then
        return machine.."-"..machine_arch
    else
        return machine
    end
end

local function validate_config(config)
    -- validate the config
    -- check if the config is valid
    -- if not, throw an error

    local err_msg = ""
    local err_code = 0

    -- check if required keys are present in config or not
    local required_keys = {"architecture", "filesystem", "interface", "encryption", "linuxboot_edk2"}
    for _, key in ipairs(required_keys) do
        if config[key] == nil then
            err_code = 1
            err_msg = err_msg.."Required key "..key.." is missing in config\n"
        end
    end

    return err_code, err_msg
end

local function validate_evaluated_config(config)

end

-- function that finds flavor from arch name and returns it
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

--------------------------------------------------------------------------------
--                                update_freebsd_img_cache
--------------------------------------------------------------------------------

local function get_img_filename(machine_combo, flavor, version)
    local filename ="FreeBSD-"..version.."-RELEASE-"..machine_combo.."-"..flavor
    return filename
end
local function get_img_url(machine, machine_arch, img_filename, version)
    local url = build.URLBASE.."/"..machine.."/"..machine_arch.."/ISO-IMAGES/"..version.."/"..img_filename..".xz"
    return url
end

local function update_freebsd_img(file, img_url)
    -- if file exists in cache, return
    local filepath = build.CACHE_DIR.."/"..file..".xz"
    if utils.file_exists(filepath) then
        return
    end
    -- else we download the image
    utils.fetch(img_url, filepath)
    -- extract that image
    utils.execute("xz -d "..filepath)
end

-- function updates freebsd_img_cache
local function update_freebsd_img_cache(machine, machine_arch, flavor, version)
    -- check if image exists in cache
    local machine_combo = get_machine_combo(machine, machine_arch)
    local file = get_img_filename(machine_combo, flavor, version)
    local img_url = get_img_url(machine, machine_arch, file, version)
    update_freebsd_img(file, img_url)
end

--------------------------------------------------------------------------------
--                                make_freebsd_minimal_trees
--------------------------------------------------------------------------------

local function make_freebsd_minimal_trees()

end

--------------------------------------------------------------------------------
--                                make_freebsd_test_trees
--------------------------------------------------------------------------------
local function make_freebsd_test_trees()

end

local function make_freebsd_esps()

end

local function make_freebsd_images()

end


local function make_freebsd_scripts(machine, machine_arch)
    local machine_combo = get_machine_combo(machine, machine_arch)
    local bios_code = build.BIOS_DIR.."/edk2-"..machine_combo.."-code.fd"
    local bios_vars = build.BIOS_DIR.."/edk2-"..machine_combo.."-vars.fd"

    if machine_arch == "amd64" then
      -- if bios code other than /usr/local/share/qemu/edk2-x86_64-code.fd
      -- then copy over to bios_code
      if bios_code ~= "/usr/local/share/qemu/edk2-x86_64-code.fd" then
        utils.execute("cp /usr/local/share/qemu/edk2-x86_64-code.fd "..bios_code)
        -- copy over vars file too
        utils.execute("cp /usr/local/share/qemu/edk2-i386-vars.fd "..bios_vars)
      end
    elseif machine_arch == "aarch64" then
      -- if bios code other than /usr/local/share/qemu/edk2-aarch64-code.fd
      -- then copy over to bios_code
      if bios_code ~= "/usr/local/share/qemu/edk2-aarch64-code.fd" then
          -- aarch64 vars starts as an empty file
          utils.execute("dd if=/dev/zero of="..bios_vars.." bs=1M count=64")
          utils.execute("dd if=/dev/zero of="..bios_code.." bs=1M count=64")
          utils.execute("dd if=/usr/local/share/qemu/edk2-aarch64-code.fd of="..bios_code.." conv=notrunc")
      end
    end
    -- make a script to run qemu
    local img = IMAGE_DIR.."/"..machine_combo.."/freebsd"..machine_combo..".img"
    local script = SCRIPT_DIR.."/"..machine_combo.."/freebsd-test.sh"

    -- make directory
    utils.execute("mkdir -p "..SCRIPT_DIR.."/"..machine_combo)

    -- set script file
    if machine_arch == "amd64" then
      local script_file = string.format([[%s -nographic -m 512M \
      -drive file=%s,if=none,id=drive0,cache=writeback,format=raw \
      -device virtio-blk,drive=drive0,bootindex=0 \
      -drive file=%s,format=raw,if=pflash \
      -monitor telnet::4444,server,nowait \
      -serial stdio $*]],
      QEMU_BIN, img, bios_code, bios_vars)

      -- save this script
      utils.write_file(script, script_file)
    elseif machine_arch == "aarch64" then
      local raw = IMAGE_DIR.."/"..machine_combo.."/nvme-test-empty.raw"

      local script_file = string.format([[%s -nographic -machine virt,gic-version=3 -m 512M \
      -cpu cortex-a57 -drive file=%s,if=none,id=drive0,cache=writeback -smp 4 \
      -device virtio-blk,drive=drive0,bootindex=0 \
      -drive file=%s,format=raw,if=pflash \
      -drive file=%s,format=raw,if=pflash \
      -drive file=%s,if=none,id=drive1,cache=writeback,format=raw \
      -device nvme,serial=deadbeef,drive=drive1 \
      -monitor telnet::4444,server,nowait \
      -serial stdio $*]],
      QEMU_BIN, img, bios_code, bios_vars, raw)

      -- save this script
      utils.write_file(script, script_file)
    end
end

----------------------------------------------------------------------------
--                             build the bootloader
----------------------------------------------------------------------------
-- write an error handler to handle errors in the build process
local function build_error_handler(err)
    print("Error: "..err)
    -- we don't exit here, return err_code, err_msg
    return 1, err
end

function build.build_freebsd_bootloader_tree(config)
    -- config will always contain two properties
    -- config.architecture : required
    -- config.regex_combination :required (not used in this context)

    -- at this point config actually has been preprocessed and contains these as well
    -- config.filesystem : required
    -- config.interface : required
    -- config.encryption : optional
    -- config.linuxboot_edk2 : set default false

    -- rest all we will figure out from the config
    -- extract required items from config
    local code, msg = validate_config(config)
    -- if code == 1 then return code, msg
    if code ~= 0 then
        return code, msg
    end

    
    -- fix if config passes ':' in the architecture
    if config.architecture:find(":") then
        config.architecture = config.architecture:sub(1, config.architecture:find(":")-1)
        config.machine_arch = config.architecture:sub(config.architecture:find(":")+1)
    end

    local machine = config.architecture             -- required
    local machine_arch = config.machine_arch or get_machine_arch(machine)
    local machine_combo = get_machine_combo(machine, machine_arch)
    local arch = machine..":"..machine_arch         -- just for consistency with previous code

    -- other important configs
    local flavour = config.flavour or find_flavour(arch)
    local filesystem = config.filesystem
    local interface = config.interface
    local encryption = nil or config.encryption
    if encryption == "none" then encryption = nil end -- bad practice, convetion already established lol
    local linuxboot_edk2 = false or config.linuxboot_edk2

    -- for updating cache
    local FREEBSD_VERSION = config.freebsd_version or build.FREEBSD_VERSION
    local img_filename = config.img_filename or get_img_filename(machine_combo, flavour, FREEBSD_VERSION)
    local img_url = config.img_url or get_img_url(machine, machine_arch, img_filename, FREEBSD_VERSION)

    -- update_freebsd_img_cache(machine, machine_arch, flavour, FREEBSD_VERSION)
    update_freebsd_img(img_filename, img_url)

    make_freebsd_minimal_trees()
    make_freebsd_test_trees()
    make_freebsd_esps()
    make_freebsd_images()
    make_freebsd_scripts()
end

function build.build_linuxboot_bootloader_tree(config)

end

function build.build_bootloader(config)
    -- build the bootloader tree
    config.linuxboot_edk2 = config.linuxboot_edk2 or "false"
    if config.linuxboot_edk2 == "true" then
        return build.build_linuxboot_bootloader_tree(config)
    else
        return build.build_freebsd_bootloader_tree(config)
    end
end

return build
--------------------------------------------------------------------------------
--                               end of module
--------------------------------------------------------------------------------