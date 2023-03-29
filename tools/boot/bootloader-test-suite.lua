-- From lua-resty-template (modified to remove external dependencies)
--[[
Copyright (c) 2014 - 2020 Aapo Talvensaari
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this
  list of conditions and the following disclaimer in the documentation and/or
  other materials provided with the distribution.

* Neither the name of the {organization} nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]--
-- $FreeBSD$

-- define several global variables
local FREEBSD_VERSION = "13.1"
local URLBASE = "https://download.freebsd.org/ftp/releases"
-- write stand root from home directory
local HOME = os.getenv("HOME")

local STAND_ROOT = HOME.."/stand"

local CACHE_DIR = STAND_ROOT.."/cache"
local IMAGE_DIR = STAND_ROOT.."/images"
local BIOS_DIR = STAND_ROOT.."/bios"
local SCRIPT_DIR = STAND_ROOT.."/scripts"
local TREE_DIR = STAND_ROOT.."/trees"
local OVERRIDES = STAND_ROOT.."/overrides"

local SRCTOP = os.execute("make -V SRCTOP")

-- QEMU binary
local QEMU_BIN = "/usr/local/bin/qemu-system-x86_64"

-- The smallest UFS filesystem is 64MB
-- The smallest ZFS filesystem is 128MB

-- The smallest FAT32 filesystem is 32MB
local espsize = 33292

-- all supported architectures
local ARCH = {"amd64:amd64", "i386:i386", "arm64:aarch64", "arm:armv7", "powerpc:powerpc", "powerpc64:powerpc64", "riscv64:riscv64", "powerpc64le:powerpc64le"}

-- die on error
local function die(msg)
    print(msg)
    os.exit(1)
end

-- execute command or die
local function execute(cmd)
    local ret = os.execute(cmd)
    if ret ~= 0 then
        die("Failed to execute "..cmd)
    end
end

-- return machine architecture combo
local function machine_combo(machine, machine_arch)
  if machine ~= machine_arch then
    return machine.."-"..machine_arch
  else
    return machine
  end
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

-- make above directories
local function mkdirs()
  local dirs = {STAND_ROOT, CACHE_DIR, IMAGE_DIR, BIOS_DIR, SCRIPT_DIR, TREE_DIR, OVERRIDES}
  for _, dir in ipairs(dirs) do
    execute("mkdir -p "..dir)
  end
end

mkdirs()


-- download freebsd image using 

-- download freebsd image using curl
local function download_freebsd_img(arch, flavour)
    local machine, machine_arch = string.match(ARCH[arch], "(%w+):(%w+)")
    local machine_combo = machine_combo(machine, machine_arch)
    local file="FREEBSD-"..FREEBSD_VERSION.."-RELEASE-"..machine_combo.."-"..flavour
    local url = URLBASE.."/"..machine.."/"..machine_arch.."/ISO-IMAGES/"..FREEBSD_VERSION.."/"..file..".xz"

    -- make sure CACHE_DIR exists
    execute("mkdir -p "..CACHE_DIR)

    -- check if file exists
    local f = io.open(CACHE_DIR.."/"..file..".xz", "r")
    if f ~= nil then
        io.close(f)
        return
    end

    -- else download file using fetch from freebsd or die
    execute("fetch -o "..CACHE_DIR.."/"..file..".xz "..url)
    -- uncompress the file or die
    execute("xz -d "..CACHE_DIR.."/"..file..".xz")
end


-- update freebsd img cache
local function update_freebsd_img_cache()
    -- download freebsd image cache for all supported architectures
    for arch in pairs(ARCH) do
        local machine, machine_arch = string.match(ARCH[arch], "(%w+):(%w+)")
        local machine_combo = machine_combo(machine, machine_arch)
        local flavour = find_flavour(arch)
        download_freebsd_img(arch, flavour)
    end
end

local function make_minimal_freebsd_tree(arch)
  local machine, machine_arch = string.match(ARCH[arch], "(%w+):(%w+)")
  local machine_combo = machine_combo(machine, machine_arch)
  local flavour = find_flavour(arch)
  local file="FREEBSD-"..FREEBSD_VERSION.."-RELEASE-"..machine_combo.."-"..flavour
  local tree = TREE_DIR.."/"..machine_combo.."/freebsd"
  -- clean up tree
  execute("rm -rf "..tree)
  -- make tree
  execute("mkdir -p "..tree)

  -- make required dirs
  local dirs = {"boot/kernel", "boot/defaults", "boot/lua", "boot/loader.conf.d",
      "sbin", "bin", "lib", "libexec", "etc", "dev"}
  for _, dir in ipairs(dirs) do
    execute("mkdir -p "..tree..dir)
  end

  -- don't have separate /usr
  execute("ln -s / "..tree.."/usr")

  -- snag binaries for simple /etc/rc/file
  execute("tar -C "..tree.." -xf "..CACHE_DIR.."/"..file.." -s 'sbin/reboot' 'sbin/halt' 'sbin/init' 'sbin/sysctl' \
      'lib/libncursesw.so.9' 'lib/libc.so' 'lib/libedit.so.8' 'libexec/ld-elf.so.1'")
  
  -- simple etc/rc
  local rc = [[
#!/bin/sh
sysctl machdep.bootmethod
echo "RC COMMAND RUNNING -- SUCCESS!!!"
halt -p
]]
  -- save above rc
  local f = io.open(tree.."/etc/rc", "w")
  f:write(rc)
  f:close()
  -- make it executable
  execute("chmod +x "..tree.."/etc/rc")

  -- check to see if we have overrides here ... insert our own kernel
  -- print checking for overrides
  print("Checking for overrides for "..machine_combo)

  -- check for overrides
  local f = io.open(OVERRIDES.."/"..machine_combo.."/boot", "r")
  if f ~= nil then
    io.close(f)
    -- write above bash code in lua 
    local o = OVERRIDES.."/"..machine_combo
    local files = {"boot/device.hints", "boot/kernel/kernel", "boot/kernel/acl_nfs4.ko", "boot/kernel/cryptodev.ko", "boot/kernel/zfs.ko", "boot/kernel/geom_eli.ko"}
    for _, file in ipairs(files) do
      local f = io.open(o.."/"..file, "r")
      if f ~= nil then
        io.close(f)
        print("Copying override "..file)
        execute("cp "..o.."/"..file.." "..tree.."/"..file)
      end
    end
    -- else
    -- Copy the kernel (but not the boot loader, we'll add the one to test later)
    -- This will take care of both UFS and ZFS boots as well as geli
    --  Note: It's OK for device.hints to be missing. It's mostly for legacy platforms.
  else
    -- Copy the kernel (but not the boot loader, we'll add the one to test later)
    -- This will take care of both UFS and ZFS boots as well as geli
    --  Note: It's OK for device.hints to be missing. It's mostly for legacy platforms.
    execute("tar -C "..tree.." -xf "..CACHE_DIR.."/"..file.." -s \
        'boot/kernel/kernel' \
        'boot/kernel/acl_nfs4.ko' \
        'boot/kernel/cryptodev.ko' \
        'boot/kernel/zfs.ko' \
        'boot/kernel/geom_eli.ko' \
        'boot/device.hints'")
  end

  -- setup some common settings for serial console
  -- append some config to boot.config
  execute("echo '-h -D -S115200' >> "..tree.."/boot/loader.conf")

  local loader_conf = [[
comconsole_speed=115200
autoboot_delay=2
zfs_load="YES"
boot_verbose=yes
kern.cfg.order="acpi,fdt"
]]
  -- save above loader_conf
  local f = io.open(tree.."/boot/loader.conf", "w")
  f:write(loader_conf)
  f:close()

end

local function make_freebsd_minimal_trees()
  for arch in pairs(ARCH) do
    make_minimal_freebsd_tree(arch)
  end
end

local function make_freebsd_test_trees()
    for arch in pairs(ARCH) do
      local machine, machine_arch = string.match(ARCH[arch], "(%w+):(%w+)")
      local machine_combo = machine_combo(machine, machine_arch)
      local tree = TREE_DIR.."/"..machine_combo.."/test-stand"

      execute("mkdir -p "..tree)

      execute("mktree -deUW -f "..SRCTOP.."/etc/mtree/BSD.root.dist -p "..tree)
      print("Creating tree for "..machine_combo)
      os.execute("cd "..SRCTOP.."/stand")

      -- TODO: understand bash code for SHELL
      -- build
      local SHELL = "make -j 100 all" -- build all
      execute("make buildenv TARGET="..machine.." TARGET_ARCH="..machine_arch)

      execute("rm -rf "..tree.."/bin")
      execute("rm -rf "..tree.."/[ac-z]*")

    end

end

-- all script routines
print("src/stand is "..STAND_ROOT)
update_freebsd_img_cache()
make_freebsd_minimal_trees()
make_freebsd_test_trees()
make_freebsd_esps()
make_freebsd_images()
make_freebsd_scripts()
