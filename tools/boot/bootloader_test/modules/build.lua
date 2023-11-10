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
    VIRTUAL_DEVICE_ID = 3,

    _version = "0.1.0",
    _name = "build",
    _description = "A library of functions for building the bootloader",
    _license = "BSD 3-Clause"
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

build.get_machine_combo = freebsd_utils.get_machine_combo

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

local function do_mount(file, mnt_dir)
    -- create a virtual device
    logger.info(string.format("Mounting: %s at Mount Point: %s",file, mnt_dir))
    utils.execute("mdconfig -a -t vnode -f "..file.." -u "..build.VIRTUAL_DEVICE_ID)
    utils.execute("mount -t ufs /dev/md"..build.VIRTUAL_DEVICE_ID.."s2a "..mnt_dir)
end

local function do_unmount(mnt_dir)
    logger.debug("Removing Mount Dir: "..mnt_dir)
    -- remove virtual device
    utils.execute("umount "..mnt_dir)
    utils.execute("mdconfig -d -u "..build.VIRTUAL_DEVICE_ID)
    logger.info("Removed Mount Dir: "..mnt_dir)
end

local function teardown_build_env()
    -- do_unmount("/mnt/armv7")
end


local function update_freebsd_img(file, img_url)
    -- if file exists in cache, return (NOTE: not .xz)
    logger.debug("Checking if file "..file.." exists in cache")
    -- first check if .iso or .img file already exists ? then exit
    if utils.file_exists(build.CACHE_DIR.."/"..file) then
        logger.info("File "..file.." already exists in cache, skipping download")
        return
    end
    logger.info("File "..file.." does not exist in cache, downloading")
    local filepath = build.CACHE_DIR.."/"..file..".xz"
    -- else we download the image
    utils.fetch_file(img_url, filepath)
    -- extract that image
    utils.execute("xz -dk "..filepath)
end

-- function updates freebsd_img_cache
local function update_freebsd_img_cache(machine, machine_arch, flavor, version)
    -- check if image exists in cache
    local machine_combo = build.get_machine_combo(machine, machine_arch)
    local file = get_img_filename(machine_combo, flavor, version)
    local img_url = get_img_url(build.URLBASE, machine, machine_arch, version)
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

build.get_rc_conf = freebsd_utils.get_rc_conf
build.get_loader_conf = freebsd_utils.get_loader_conf

local function make_freebsd_minimal_trees(machine, machine_arch, img_filename, rc_conf, loader_conf)
    logger.debug("Making freebsd minimal trees")
    -- local img_filename = img_filename         -- e.g. FREEBSD-13.0-RELEASE-amd64-bootonly.iso
    local machine_combo = build.get_machine_combo(machine, machine_arch)  -- e.g. amd64-amd64
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
    if machine_arch == "armv7" then
        -- try to look for files at mnt point for now assume /mnt/armv7
        os.execute("mkdir -p /mnt/armv7")
        local check_mnt = utils.check_files("/mnt/armv7/")
        if not check_mnt then
            do_mount(build.CACHE_DIR.."/"..img_filename, "/mnt/armv7")
        else
            logger.warn("/mnt/armv7 is not empty. Using already mounted files!")
        end
        local files = "sbin/reboot sbin/halt sbin/init bin/sh sbin/sysctl lib/libncursesw.so.9 lib/libc.so.7 lib/libgcc_s.so.1 lib/libedit.so.8 libexec/ld-elf.so.1"
        logger.debug("Copying files from /mnt/armv7")
        for file in files:gmatch("%S+") do
            -- utils.execute("echo cp -r /mnt/armv7/"..file.."")
            utils.execute(string.format("cp -r /mnt/armv7/%s %s/%s || true",file,tree,file))
        end
        logger.debug("Copied files successfully!")
    else
        logger.debug("Extracting binaries from "..build.CACHE_DIR.."/"..img_filename)
        utils.execute("tar -C "..tree.." -xf "..build.CACHE_DIR.."/"..img_filename.." sbin/reboot sbin/halt sbin/init bin/sh sbin/sysctl lib/libncursesw.so.9 lib/libc.so.7 lib/libedit.so.8 libexec/ld-elf.so.1")    
    end
    -- simple etc/rc
    -- save rc in a file, but due to weird lua io.open() behaviour, we need create a file first
    -- make it executable
    logger.debug("Writing rc.conf to "..tree.."/etc/rc")
    local rc = rc_conf or build.get_rc_conf(machine, machine_arch)
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
        if machine_arch == "armv7" then
            local files = "boot/kernel/kernel boot/kernel/acl_nfs4.ko boot/kernel/cryptodev.ko boot/kernel/zfs.ko boot/kernel/geom_eli.ko boot/device.hints"
            logger.debug("Copying files from /mnt/armv7")
            utils.copy_files_from_list(files, "/mnt/armv7", tree)
            do_unmount("/mnt/armv7")
            logger.debug("Copied files successfully!")
        else
            utils.execute("tar -C "..tree.." -xf "..build.CACHE_DIR.."/"..img_filename.." boot/kernel/kernel boot/kernel/acl_nfs4.ko boot/kernel/cryptodev.ko boot/kernel/zfs.ko boot/kernel/geom_eli.ko boot/device.hints || true")
        end
    end

    -- setup some common settings for serial console
    -- append some config to boot.config
    utils.execute("echo '-h -D -S115200' >> "..tree.."/boot/loader.conf")

    -- loader config
    logger.debug("Writing loader.conf to "..tree.."/boot/loader.conf")
    local loader = loader_conf or build.get_loader_conf(machine, machine_arch)
    utils.write_data_to_file(tree.."/boot/loader.conf", loader)

end

--------------------------------------------------------------------------------
--                                make_freebsd_test_trees
--------------------------------------------------------------------------------
local function make_freebsd_test_trees(machine, machine_arch)
    local machine_combo = build.get_machine_combo(machine, machine_arch)
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
build.get_boot_efi = freebsd_utils.get_boot_efi_name
local function make_freebsd_esps(machine, machine_arch)
    local machine_combo = build.get_machine_combo(machine, machine_arch)
    local tree = build.TREE_DIR.."/"..machine_combo.."/test-stand"
    local esp = build.TREE_DIR.."/"..machine_combo.."/freebsd-esp"

    -- make directory and clean up first
    utils.execute("rm -rf "..esp)
    utils.execute("mkdir -p "..esp)

    logger.debug("Copying files from "..tree.." to "..esp)
    -- make directory TREE_DIR/efi/boot
    utils.execute("mkdir -p "..esp.."/efi/boot")

    -- copy loader.efi to efi/boot/xxx.efi
    local boot_efi = build.get_boot_efi(machine_arch)
    utils.execute("cp "..tree.."/boot/loader.efi "..esp.."/efi/boot/"..boot_efi)
end
--------------------------------------------------------------------------------
--                                make_freebsd_images
--------------------------------------------------------------------------------
build.get_fstab = freebsd_utils.get_fstab_file
local function make_freebsd_images(config)
    local m, ma, fs, bi, _, identifier = freebsd_utils.parse_config(config)
    local mc = freebsd_utils.get_machine_combo(m, ma)

    local src = build.TREE_DIR.."/"..mc.."/freebsd-esp"
    local dir = build.TREE_DIR.."/"..mc.."/freebsd"
    local dir2 = build.TREE_DIR.."/"..mc.."/test-stand"
    local esp = build.IMAGE_DIR.."/"..mc.."/freebsd-"..mc..".esp"
    local fs_file = build.IMAGE_DIR.."/"..mc.."/freebsd-"..mc.."."..fs
    local img = build.IMAGE_DIR.."/"..mc.."/freebsd-"..identifier..".img"

    -- make directories
    utils.execute("mkdir -p "..build.IMAGE_DIR.."/"..mc)
    utils.execute("mkdir -p "..dir2.."/etc")

    -- set fstab file
    local fstab = build.get_fstab(fs)
    -- save this fstab file
    utils.write_data_to_file(dir2.."/etc/fstab", fstab)

    logger.debug("Creating image for "..mc)
    -- TODO(Externalisation Required): understand bash code for SHELL
    local fs_commands = {
        freebsd_utils.get_esp_recipe(esp,src),
        freebsd_utils.get_fs_recipe(fs, fs_file,dir,dir2),
        freebsd_utils.get_img_creation_cmd(esp,fs,fs_file,img, bi)
    }

    for _, cmd in ipairs(fs_commands) do
        utils.execute(cmd)
    end

end

--------------------------------------------------------------------------------
--                                make_freebsd_scripts
--------------------------------------------------------------------------------
local function make_freebsd_scripts(config)

    local m, ma, fs, bi, enc, _ = freebsd_utils.parse_config(config)
    local mc = build.get_machine_combo(m, ma)

    -- TODO: (Externalisation Required): understand how this works
    local bios_code = build.BIOS_DIR.."/edk2-"..mc.."-code.fd"
    local bios_vars = build.BIOS_DIR.."/edk2-"..mc.."-vars.fd"

    if ma == "amd64" then
      -- if bios code other than /usr/local/share/qemu/edk2-x86_64-code.fd
      -- then copy over to bios_code
      if bios_code ~= "/usr/local/share/qemu/edk2-x86_64-code.fd" then
        utils.execute("cp /usr/local/share/qemu/edk2-x86_64-code.fd "..bios_code) -- copy over vars file too
        utils.execute("cp /usr/local/share/qemu/edk2-i386-vars.fd "..bios_vars)
      end
    elseif ma == "aarch64" then
      -- if bios code other than /usr/local/share/qemu/edk2-aarch64-code.fd
      -- then copy over to bios_code
      if bios_code ~= "/usr/local/share/qemu/edk2-aarch64-code.fd" then
          -- aarch64 vars starts as an empty file
          utils.execute("dd if=/dev/zero of="..bios_vars.." bs=1M count=64")
          utils.execute("dd if=/dev/zero of="..bios_code.." bs=1M count=64")
          utils.execute("dd if=/usr/local/share/qemu/edk2-aarch64-code.fd of="..bios_code.." conv=notrunc")
      end
    elseif ma == "riscv64" then
        utils.execute("cp /usr/local/share/qemu/opensbi-riscv64-generic-fw_dynamic.bin "..bios_code)
    elseif ma == "armv7" then
        
    end
    local identifier = freebsd_utils.get_identifier(m, ma, fs, bi, enc)
    local img = build.IMAGE_DIR.."/"..mc.."/freebsd-"..identifier..".img"
    local script = build.SCRIPT_DIR.."/"..mc.."/freebsd-"..identifier..".sh"
    utils.execute("mkdir -p "..build.SCRIPT_DIR.."/"..mc)

    local qemu_script = freebsd_utils.get_qemu_script(m, ma, fs, img, bios_code, bios_vars, config.port)
    utils.write_data_to_file(script, qemu_script)
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
    local machine_combo = build.get_machine_combo(machine, machine_arch)
    local arch = machine..":"..machine_arch

    -- other important configs
    local filesystem = config.filesystem
    local interface = config.interface
    local encryption = nil or config.encryption
    if encryption == "none" then encryption = nil end -- bad practice, convetion already established lol
    local linuxboot_edk2 = config.linuxboot_edk2 

    -- for updating cache
    local flavour = config.recipe.flavour or freebsd_utils.find_flavor(arch)
    local FREEBSD_VERSION = config.recipe.freebsd_version or build.FREEBSD_VERSION
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
    update_freebsd_img_cache(machine, machine_arch, flavour, FREEBSD_VERSION)

    -- craft a minimal tree, either supply correct rc or loader conf or get them
    local rc_conf = config.rc_conf or freebsd_utils.get_rc_conf(machine, machine_arch)
    local loader_conf = config.loader_conf or freebsd_utils.get_loader_conf(machine, machine_arch)
    logger.debug("RC Conf: "..rc_conf)
    logger.debug("Loader Conf: "..loader_conf)
    make_freebsd_minimal_trees(machine, machine_arch, img_filename, rc_conf, loader_conf)

    -- make a test tree for testing
    make_freebsd_test_trees(machine, machine_arch)
    make_freebsd_esps(machine, machine_arch)
    make_freebsd_images(config)
    make_freebsd_scripts(config)
    -- if all goes well, return 0, nil
    teardown_build_env()
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
