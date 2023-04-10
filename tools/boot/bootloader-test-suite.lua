
-- $FreeBSD$

-- define several global variables
local FREEBSD_VERSION = "13.1"
local URLBASE = "https://download.freebsd.org/ftp/releases"
-- write stand root from home directory
local HOME = os.getenv("HOME")

local STAND_ROOT = HOME.."/stand-test-root"

local CACHE_DIR = STAND_ROOT.."/cache"
local IMAGE_DIR = STAND_ROOT.."/images"
local BIOS_DIR = STAND_ROOT.."/bios"
local SCRIPT_DIR = STAND_ROOT.."/scripts"
local TREE_DIR = STAND_ROOT.."/trees"
local OVERRIDES = STAND_ROOT.."/overrides"

-- this doesnt work
-- local SRCTOP = os.execute("make -V SRCTOP")
-- capture function for fixing make -V variable spawns new shell
local function capture_execute(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end
-- don't take raw values causes issues with concatenation
local SRCTOP = capture_execute("make -V SRCTOP", false)

-- QEMU binary
local QEMU_BIN = "/usr/local/bin/qemu-system-x86_64"

-- The smallest UFS filesystem is 64MB
-- The smallest ZFS filesystem is 128MB

-- The smallest FAT32 filesystem is 32MB
local espsize = 33292

-- all supported architectures
-- local ARCH = {"amd64:amd64", "i386:i386", "arm64:aarch64", "arm:armv7", "powerpc:powerpc", "powerpc64:powerpc64", "riscv64:riscv64", "powerpc64le:powerpc64le"}
local ARCH = {"amd64:amd64"}

-- die on error
local function die(msg)
    print(msg)
    os.exit(1)
end

-- execute command or die
local function execute(cmd)
    local _,msg,ret = os.execute(cmd)
    if ret ~= 0 then
        print(msg)
        die("Failed to execute "..cmd)
    end
end

-- utility function to write a file and handle all lua io.open() weirdness
local function write_file(file, data)
    -- due to weird lua io.open() behaviour, we need create a file first
    -- direct touch() syscall doesn't work in case folder doesn't exist
    execute("mkdir -p "..string.match(file, "(.+)/.+$"))
    execute("touch "..file)
    local f = io.open(file, "w")
    -- check if file is even open
    if f == nil then
        die("Failed to open file "..file)
    else
      f:write(data)
      f:close()
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
    local file="FreeBSD-"..FREEBSD_VERSION.."-RELEASE-"..machine_combo.."-"..flavour
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
  local file="FreeBSD-"..FREEBSD_VERSION.."-RELEASE-"..machine_combo.."-"..flavour
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
  execute("ln -s . "..tree.."/usr")

  -- snag binaries for simple /etc/rc/file
  execute("tar -C "..tree.." -xf "..CACHE_DIR.."/"..file.." sbin/reboot sbin/halt sbin/init sbin/sysctl lib/libncursesw.so.9 lib/libc.so.7 lib/libedit.so.8 libexec/ld-elf.so.1")
  
  -- simple etc/rc
  local rc = [[
#!/bin/sh
sysctl machdep.bootmethod
echo "RC COMMAND RUNNING -- SUCCESS!!!"
halt -p
]]
  -- save above rc in a file, but due to weird lua io.open() behaviour, we need create a file first
  write_file(tree.."/etc/rc", rc)
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
    execute("tar -C "..tree.." -xf "..CACHE_DIR.."/"..file.." boot/kernel/kernel boot/kernel/acl_nfs4.ko boot/kernel/cryptodev.ko boot/kernel/zfs.ko boot/kernel/geom_eli.ko boot/device.hints")
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
  write_file(tree.."/boot/loader.conf", loader_conf)

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

      execute("mtree -deUW -f "..SRCTOP.."/etc/mtree/BSD.root.dist -p "..tree)
      print("Creating tree for "..machine_combo)
      -- execute("cd "..SRCTOP.."/stand")
      -- TODO: understand bash code for SHELL

      execute('cd '..SRCTOP..'/stand && SHELL="make -j 100 all" make buildenv TARGET='..machine..' TARGET_ARCH='..machine_arch)
      execute('cd '..SRCTOP..'/stand && SHELL="make install DESTDIR='..tree..' MK_MAN=no MK_INSTALL_AS_USER=yes WITHOUT_DEBUG_FILES=yes" make buildenv TARGET='..machine..' TARGET_ARCH='..machine_arch)

      execute("rm -rf "..tree.."/bin")
      execute("rm -rf "..tree.."/[ac-z]*")

    end

end

-- create freebsd esps function
local function make_freebsd_esps(arch)

    for arch in pairs(ARCH) do
      local machine, machine_arch = string.match(ARCH[arch], "(%w+):(%w+)")
      local machine_combo = machine_combo(machine, machine_arch)
      local tree = TREE_DIR.."/"..machine_combo.."/test-stand"
      local esp = TREE_DIR.."/"..machine_combo.."/freebsd-esp"

      -- make directory and clean up first
      execute("rm -rf "..esp)
      execute("mkdir -p "..esp)

      -- make directory TREE_DIR/efi/boot
      execute("mkdir -p "..esp.."/efi/boot")
      if machine_arch == "amd64" then
        execute("cp "..tree.."/boot/loader.efi "..esp.."/efi/boot/bootx64.efi")
      elseif machine_arch == "i386" then
        execute("cp "..tree.."/boot/loader.efi "..esp.."/efi/boot/bootia32.efi")
      elseif machine_arch == "arm64" then
        execute("cp "..tree.."/boot/loader.efi "..esp.."/efi/boot/bootaa64.efi")
      elseif machine_arch == "arm" then
        execute("cp "..tree.."/boot/loader.efi "..esp.."/efi/boot/bootarm.efi")
      end

    end
  
end

local function make_freebsd_images()
  for arch in pairs(ARCH) do
    local machine, machine_arch = string.match(ARCH[arch], "(%w+):(%w+)")
    local machine_combo = machine_combo(machine, machine_arch)
    local src = TREE_DIR.."/"..machine_combo.."/freebsd-esp"
    local dir = TREE_DIR.."/"..machine_combo.."/freebsd"
    local dir2 = TREE_DIR.."/"..machine_combo.."/test-stand"
    local esp = IMAGE_DIR.."/"..machine_combo.."/freebsd"..machine_combo..".esp"
    local ufs = IMAGE_DIR.."/"..machine_combo.."/freebsd"..machine_combo..".ufs"
    local img = IMAGE_DIR.."/"..machine_combo.."/freebsd"..machine_combo..".img"

    -- make directories
    execute("mkdir -p "..IMAGE_DIR.."/"..machine_combo)
    execute("mkdir -p "..dir2.."/etc")

    -- set fstab file
    local fstab = [[
/dev/ufs/freebsd / ufs rw 1 1
]]
    -- save this fstab file
    write_file(dir2.."/etc/fstab", fstab)

    -- makefs command
    execute("makefs -t msdos -o fat_type=32 -o sectors_per_cluster=1 -o volume_label=EFISYS -s100m "..esp.." "..src)
    -- makefs command for ufs
    execute("makefs -t ffs -B little -s 200m -o label=root "..ufs.." "..dir.." "..dir2)
    -- makeimg image
    execute("mkimg -s gpt -p efi:="..esp.." -p freebsd-ufs:="..ufs.." -o "..img)

  end
  
end


local function make_freebsd_scripts()
  for arch in pairs(ARCH) do
    local machine, machine_arch = string.match(ARCH[arch], "(%w+):(%w+)")
    local machine_combo = machine_combo(machine, machine_arch)
    local bios_code = BIOS_DIR.."/edk2-"..machine_combo.."-code.fd"
    local bios_vars = BIOS_DIR.."/edk2-"..machine_combo.."-vars.fd"

    if machine_arch == "amd64" then
      -- if bios code other than /usr/local/share/qemu/edk2-x86_64-code.fd
      -- then copy over to bios_code
      if bios_code ~= "/usr/local/share/qemu/edk2-x86_64-code.fd" then
        execute("cp /usr/local/share/qemu/edk2-x86_64-code.fd "..bios_code)
        -- copy over vars file too
        execute("cp /usr/local/share/qemu/edk2-i386-vars.fd "..bios_vars)
      end
    elseif machine_arch == aarch64 then
      -- if bios code other than /usr/local/share/qemu/edk2-aarch64-code.fd
      -- then copy over to bios_code
      if bios_code ~= "/usr/local/share/qemu/edk2-aarch64-code.fd" then
          -- aarch64 vars starts as an empty file
          execute("dd if=/dev/zero of="..bios_vars.." bs=1M count=64")
          execute("dd if=/dev/zero of="..bios_code.." bs=1M count=64")
          execute("dd if=/usr/local/share/qemu/edk2-aarch64-code.fd of="..bios_code.." conv=notrunc")
      end
    end
    -- make a script to run qemu
    local img = IMAGE_DIR.."/"..machine_combo.."/freebsd"..machine_combo..".img"
    local script = SCRIPT_DIR.."/"..machine_combo.."/freebsd-test.sh"

    -- make directory
    execute("mkdir -p "..SCRIPT_DIR.."/"..machine_combo)

    -- set script file
    if machine_arch == "amd64" then
      local script_file = string.format("%s/qemu-system-x86_64 -nographic -m 512M \
      -drive file=%s,if=none,id=drive0,cache=writeback,format=raw \
      -device virtio-blk,drive=drive0,bootindex=0 \
      -drive file=%s,format=raw,if=pflash \
      -drive file=%s,format=raw,if=pflash \
      -monitor telnet::4444,server,nowait \
      -serial stdio \\$*",
      QEMU_BIN, img, bios_code, bios_vars)

      -- save this script
      local f = io.open(script, "w")
      f:write(script_file)
      f:close()
    elseif machine_arch == "aarch64" then
      local raw = IMAGE_DIR.."/"..machine_combo.."/nvme-test-empty.raw"

      local script_file = string.format("%s/qemu-system-aarch64 -nographic -machine virt,gic-version=3 -m 512M \
      -cpu cortex-a57 -drive file=%s,if=none,id=drive0,cache=writeback -smp 4 \
      -device virtio-blk,drive=drive0,bootindex=0 \
      -drive file=%s,format=raw,if=pflash \
      -drive file=%s,format=raw,if=pflash \
      -drive file=%s,if=none,id=drive1,cache=writeback,format=raw \
      -device nvme,serial=deadbeef,drive=drive1 \
      -monitor telnet::4444,server,nowait \
      -serial stdio \\$*",
      QEMU_BIN, img, bios_code, bios_vars, raw)

      -- save this script
      local f = io.open(script, "w")
      f:write(script_file)
      f:close()
      
    end
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
