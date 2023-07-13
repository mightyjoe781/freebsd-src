#!/usr/libexec/flua

--------------------------------------------------------------------------------
--                                import modules
--------------------------------------------------------------------------------
local freebsd_utils = require('modules.freebsd_utils')
local utils = require('modules.utils')
local posix = require('posix')
local parser = require('modules.parser')
local logger = require('modules.logger')


--------------------------------------------------------------------------------
--                                constants
--------------------------------------------------------------------------------
local HOME = os.getenv("HOME")
local QEMU_BIN = "/usr/local/bin/qemu-system-x86_64"

local STAND_ROOT = HOME.."/stand-test-root"
local SRCTOP = utils.capture_execute("make -V SRCTOP", false)
-- local BIOS_DIR = STAND_ROOT.."/bios"
-- local CACHE_DIR = STAND_ROOT.."/cache"
-- local IMAGE_DIR = STAND_ROOT.."/images"
-- local OVERRIDES = STAND_ROOT.."/overrides"
-- local SCRIPT_DIR = STAND_ROOT.."/scripts"
-- local TREE_DIR = STAND_ROOT.."/trees"

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

build.get_machine_arch = freebsd_utils.get_machine_arch
local get_machine_combo = build.get_machine_combo
local find_flavour = freebsd_utils.find_flavour

local function validate_config(config)
    -- validate the config
    -- check if the config is valid
    -- if not, throw an error

    local err_msg = ""
    local err_code = 0

    -- check if required keys are present in config or not
    local required_keys = {"architecture", "filesystem", "interface", "encryption", "linuxboot_edk2", "machine", "machine_arch"}
    for _, key in ipairs(required_keys) do
        if config[key] == nil then
            err_code = 1
            err_msg = err_msg.."Required key "..key.." is missing in config\n"
        end
    end

    return err_code, err_msg
end

--------------------------------------------------------------------------------
--                                update_freebsd_img_cache
--------------------------------------------------------------------------------

local get_img_filename = freebsd_utils.get_img_filename
local get_img_url = freebsd_utils.get_img_url

local function update_freebsd_img(file, img_url)
    -- if file exists in cache, return
    local filepath = build.CACHE_DIR.."/"..file..".xz"
    logger.debug("Checking if file "..filepath.." exists in cache")
    if utils.file_exists(filepath) then
        logger.info("File "..filepath.." already exists in cache, skipping download")
        return
    end
    logger.info("File "..filepath.." does not exist in cache, downloading")
    -- else we download the image
    utils.fetch_file(img_url, filepath)
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
local function check_override(machine_combo)
    -- check files exist in overrides
    -- first check if directory exists
    if not utils.dir_exists(build.OVERRIDES.."/"..machine_combo) then
        return false, "Directory "..build.OVERRIDES.."/"..machine_combo.." does not exist"
    end
    local o = build.OVERRIDES.."/"..machine_combo
    local files = {"boot/device.hints", "boot/kernel/kernel", "boot/kernel/acl_nfs4.ko", "boot/kernel/cryptodev.ko", "boot/kernel/zfs.ko", "boot/kernel/geom_eli.ko"}
    -- check all files exists in directory
    for _, file in ipairs(files) do
        if not utils.file_exists(o.."/"..file) then
            return false, "File "..o.."/"..file.." does not exist"
        end
    end
    return true, ""
end

local function get_rc_conf(machine, machine_arch)
    -- simple etc/rc
    local rc = [[
#!/bin/sh
sysctl machdep.bootmethod
echo "RC COMMAND RUNNING -- SUCCESS!!!"
halt -p
]]
    return rc
end

local function get_loader_conf(machine, machine_arch)
    -- simple boot/loader.conf
    local loader = [[
comconsole_speed=115200
autoboot_delay=2
zfs_load="YES"
boot_verbose=yes
kern.cfg.order="acpi,fdt"
]]
    return loader
end

local function make_freebsd_minimal_trees(machine, machine_arch, img_filename, rc_conf, loader_conf)
    logger.debug("Making freebsd minimal trees")
    -- local img_filename = img_filename         -- e.g. FREEBSD-13.0-RELEASE-amd64-bootonly.iso
    local machine_combo = get_machine_combo(machine, machine_arch)  -- e.g. amd64-amd64
    local tree = build.TREE_DIR.."/"..machine_combo.."/freebsd/"   -- e.g. /trees/arm64-aarch64/freebsd
    logger.debug("Making freebsd minimal trees for "..machine_combo.." in "..tree)

    -- clean up tree & make tree
    utils.execute("rm -rf "..tree)
    utils.execute("mkdir -p "..tree)

    -- make required dirs
    local dirs = {"boot/kernel", "boot/defaults", "boot/lua", "boot/loader.conf.d",
        "sbin", "bin", "lib", "libexec", "etc", "dev"}
    for _, dir in ipairs(dirs) do
        utils.execute("mkdir -p "..tree..dir)
    end

    -- don't have separate /usr
    utils.execute("ln -s . "..tree.."/usr")

    -- snag binaries for simple /etc/rc/file
    logger.debug("Extracting binaries from "..build.CACHE_DIR.."/"..img_filename)
    utils.execute("tar -C "..tree.." -xf "..build.CACHE_DIR.."/"..img_filename.." sbin/reboot sbin/halt sbin/init bin/sh sbin/sysctl lib/libncursesw.so.9 lib/libc.so.7 lib/libedit.so.8 libexec/ld-elf.so.1")
  
    -- simple etc/rc
    -- save rc in a file, but due to weird lua io.open() behaviour, we need create a file first
    -- make it executable
    logger.debug("Writing rc.conf to "..tree.."/etc/rc")
    local rc = rc_conf or get_rc_conf(machine, machine_arch)
    utils.write_data_to_file(tree.."/etc/rc", rc)
    utils.execute("chmod +x "..tree.."/etc/rc")

    -- check to see if we have overrides here ... insert our own kernel
    logger.debug("Checking for overrides for "..machine_combo)
    local found, err_msg = check_override(machine_combo)
    if found then
        logger.debug("Found overrides for "..machine_combo)
        -- copy overrides
        local o = build.OVERRIDES.."/"..machine_combo
        local files = {"boot/device.hints", "boot/kernel/kernel", "boot/kernel/acl_nfs4.ko",
         "boot/kernel/cryptodev.ko", "boot/kernel/zfs.ko", "boot/kernel/geom_eli.ko"}
        for _, file in ipairs(files) do
            local f = io.open(o.."/"..file, "r")
            if f ~= nil then
                io.close(f)
                print("Copying override "..file)
                utils.execute("cp "..o.."/"..file.." "..tree.."/"..file)
            end
        end
    else
        logger.debug("No overrides found for "..machine_combo)
        logger.debug("Using default kernel")
        -- copy kernel from image
        utils.execute("tar -C "..tree.." -xf "..build.CACHE_DIR.."/"..img_filename.." boot/kernel/kernel boot/kernel/acl_nfs4.ko boot/kernel/cryptodev.ko boot/kernel/zfs.ko boot/kernel/geom_eli.ko boot/device.hints")
    end

    -- setup some common settings for serial console
    -- append some config to boot.config
    utils.execute("echo '-h -D -S115200' >> "..tree.."/boot/loader.conf")

    -- loader config
    logger.debug("Writing loader.conf to "..tree.."/boot/loader.conf")
    local loader = loader_conf or get_loader_conf(machine, machine_arch)
    utils.write_data_to_file(tree.."/boot/loader.conf", loader)

end

--------------------------------------------------------------------------------
--                                make_freebsd_test_trees
--------------------------------------------------------------------------------
local function make_freebsd_test_trees(machine, machine_arch)
    local machine_combo = get_machine_combo(machine, machine_arch)
    local tree = build.TREE_DIR.."/"..machine_combo.."/test-stand"

    utils.execute("mkdir -p "..tree)

    logger.debug("Creating tree for "..machine_combo)
    utils.execute("mtree -deUW -f "..SRCTOP.."/etc/mtree/BSD.root.dist -p "..tree)
    print("Creating tree for "..machine_combo)
    -- execute("cd "..SRCTOP.."/stand")
    -- TODO: understand bash code for SHELL

    logger.debug("Building test-stand for "..machine_combo)
    utils.execute('cd '..SRCTOP..'/stand && SHELL="make -j 100 all" make buildenv TARGET='..machine..' TARGET_ARCH='..machine_arch)
    utils.execute('cd '..SRCTOP..'/stand && SHELL="make install DESTDIR='..tree..' MK_MAN=no MK_INSTALL_AS_USER=yes WITHOUT_DEBUG_FILES=yes" make buildenv TARGET='..machine..' TARGET_ARCH='..machine_arch)

    logger.debug("Removing unnecessary files from "..tree)
    utils.execute("rm -rf "..tree.."/bin")
    utils.execute("rm -rf "..tree.."/[ac-z]*")
end

--------------------------------------------------------------------------------
--                                make_freebsd_esps
--------------------------------------------------------------------------------
local function make_freebsd_esps(machine, machine_arch)
    local machine_combo = get_machine_combo(machine, machine_arch)
    local tree = build.TREE_DIR.."/"..machine_combo.."/test-stand"
    local esp = build.TREE_DIR.."/"..machine_combo.."/freebsd-esp"

    -- make directory and clean up first
    utils.execute("rm -rf "..esp)
    utils.execute("mkdir -p "..esp)

    logger.debug("Copying files from "..tree.." to "..esp)
    -- make directory TREE_DIR/efi/boot
    utils.execute("mkdir -p "..esp.."/efi/boot")
    if machine_arch == "amd64" then
        utils.execute("cp "..tree.."/boot/loader.efi "..esp.."/efi/boot/bootx64.efi")
    elseif machine_arch == "i386" then
        utils.execute("cp "..tree.."/boot/loader.efi "..esp.."/efi/boot/bootia32.efi")
    elseif machine_arch == "arm64" then
        utils.execute("cp "..tree.."/boot/loader.efi "..esp.."/efi/boot/bootaa64.efi")
    elseif machine_arch == "arm" then
        utils.execute("cp "..tree.."/boot/loader.efi "..esp.."/efi/boot/bootarm.efi")
    end
end
--------------------------------------------------------------------------------
--                                make_freebsd_images
--------------------------------------------------------------------------------
local function make_freebsd_images(machine, machine_arch)
    local machine_combo = get_machine_combo(machine, machine_arch)

    local src = build.TREE_DIR.."/"..machine_combo.."/freebsd-esp"
    local dir = build.TREE_DIR.."/"..machine_combo.."/freebsd"
    local dir2 = build.TREE_DIR.."/"..machine_combo.."/test-stand"
    local esp = build.IMAGE_DIR.."/"..machine_combo.."/freebsd-"..machine_combo..".esp"
    local ufs = build.IMAGE_DIR.."/"..machine_combo.."/freebsd-"..machine_combo..".ufs"
    local img = build.IMAGE_DIR.."/"..machine_combo.."/freebsd-"..machine_combo..".img"

    -- make directories
    utils.execute("mkdir -p "..build.IMAGE_DIR.."/"..machine_combo)
    utils.execute("mkdir -p "..dir2.."/etc")

    -- set fstab file
    local fstab = [[
/dev/ufs/root / ufs rw 1 1
]]
    -- save this fstab file
    utils.write_data_to_file(dir2.."/etc/fstab", fstab)

    logger.debug("Creating image for "..machine_combo)
    -- makefs command
    utils.execute("makefs -t msdos -o fat_type=32 -o sectors_per_cluster=1 -o volume_label=EFISYS -s100m "..esp.." "..src)
    -- makefs command for ufs
    utils.execute("makefs -t ffs -B little -s 200m -o label=root "..ufs.." "..dir.." "..dir2)
    -- makeimg image
    utils.execute("mkimg -s gpt -p efi:="..esp.." -p freebsd-ufs:="..ufs.." -o "..img)

end

--------------------------------------------------------------------------------
--                                make_freebsd_scripts
--------------------------------------------------------------------------------
local function make_freebsd_scripts(machine, machine_arch)

    local machine_combo = get_machine_combo(machine, machine_arch)
    local bios_code = build.BIOS_DIR.."/edk2-"..machine_combo.."-code.fd"
    local bios_vars = build.BIOS_DIR.."/edk2-"..machine_combo.."-vars.fd"

    if machine_arch == "amd64" then
      -- if bios code other than /usr/local/share/qemu/edk2-x86_64-code.fd
      -- then copy over to bios_code
      if bios_code ~= "/usr/local/share/qemu/edk2-x86_64-code.fd" then
        utils.execute("cp /usr/local/share/qemu/edk2-x86_64-code.fd "..bios_code) -- copy over vars file too
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
    local img = build.IMAGE_DIR.."/"..machine_combo.."/freebsd-"..machine_combo..".img"
    local script = build.SCRIPT_DIR.."/"..machine_combo.."/freebsd-test.sh"

    -- make directory
    utils.execute("mkdir -p "..build.SCRIPT_DIR.."/"..machine_combo)

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
      utils.write_data_to_file(script, script_file)
    elseif machine_arch == "aarch64" then
      local raw = build.IMAGE_DIR.."/"..machine_combo.."/nvme-test-empty.raw"

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
      utils.write_data_to_file(script, script_file)
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
    
    logger.info("Validating config")
    local code, msg = validate_config(config)
    if code ~= 0 then
        logger.info("Validation failed")
        logger.info("Error: "..msg)
        logger.info(utils.print_table(config))
        return code, msg
    end
    logger.info("Validation passed")

    local machine = config.machine
    local machine_arch = config.machine_arch
    local machine_combo = get_machine_combo(machine, machine_arch)
    local arch = machine..":"..machine_arch

    -- other important configs
    local filesystem = config.filesystem
    local interface = config.interface
    local encryption = nil or config.encryption
    if encryption == "none" then encryption = nil end -- bad practice, convetion already established lol
    local linuxboot_edk2 = config.linuxboot_edk2 

    -- for updating cache
    local flavour = config.flavour or find_flavour(arch)
    local FREEBSD_VERSION = config.freebsd_version or build.FREEBSD_VERSION
    local img_filename = config.img_filename or freebsd_utils.get_img_filename(machine_combo, flavour, FREEBSD_VERSION)
    local img_url = config.img_url or freebsd_utils.get_img_url(machine, machine_arch, img_filename, FREEBSD_VERSION)


    -- log all the configs important for this build
    logger.debug("Arch:             "..arch)
    logger.debug("Machine:          "..machine)
    logger.debug("Machine Arch:     "..machine_arch)
    logger.debug("Machine Combo:    "..machine_combo)
    logger.debug("Filesystem:       "..filesystem)
    logger.debug("Interface:        "..interface)
    if encryption ~= nil then 
        logger.debug("Encryption:        "..encryption) 
    else  
        logger.debug("Encryption:        None")
    end
    logger.debug("Flavour:          "..flavour)
    logger.debug("Linuxboot EDK2:   "..tostring(linuxboot_edk2))
    logger.debug("FreeBSD Version:  "..FREEBSD_VERSION)
    logger.debug("Image Filename:   "..img_filename)
    logger.debug("Image URL: "..img_url)

    -- update_freebsd_img_cache(machine, machine_arch, flavour, FREEBSD_VERSION)
    update_freebsd_img(img_filename, img_url)

    -- craft a minimal tree, either supply correct rc or loader conf or get them
    local rc_conf = config.rc_conf or get_rc_conf(machine, machine_arch)
    local loader_conf = config.loader_conf or get_loader_conf(machine, machine_arch)
    logger.debug("RC Conf: "..rc_conf)
    logger.debug("Loader Conf: "..loader_conf)
    make_freebsd_minimal_trees(machine, machine_arch, img_filename, rc_conf, loader_conf)

    -- make a test tree for testing
    make_freebsd_test_trees(machine, machine_arch)
    make_freebsd_esps(machine, machine_arch)
    make_freebsd_images(machine, machine_arch)
    make_freebsd_scripts(machine, machine_arch)
    -- if all goes well, return 0, nil
    return 0, nil
end

function build.build_linuxboot_bootloader_tree(config)
    print("Building linuxboot bootloader tree")
end

local function setup_build_env()
    -- create all build directories
    -- for each directory in build.*_DIR

    logger.debug("Creating build directories")
    local dirs = {
        build.CACHE_DIR,
        build.IMAGE_DIR,
        build.BIOS_DIR,
        build.SCRIPT_DIR,
        build.TREE_DIR,
        build.OVERRIDES
    }
    for _, dir in ipairs(dirs) do
        logger.debug("Creating directory "..dir)
        utils.execute("mkdir -p "..dir)
    end

end

function build.build_bootloader(config)
    -- build the bootloader tree
    setup_build_env()
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