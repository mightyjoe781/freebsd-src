#!/usr/libexec/flua

local freebsd_utils = {
    -- list of arch and machine arch combinations : machine:machine_arch
    arch_list = {
        "amd64:amd64",
        "i386:i386",
        "arm64:aarch64",
        "arm:armv7",
        "powerpc:powerpc",
        "powerpc64:powerpc64",
        "riscv64:riscv64",
        "powerpc64le:powerpc64le"
    },

    _version = "0.1.0",
    _name = "freebsd_utils",
    _description = "freebsd utils module",
    _license = "BSD 3-Clause"
}

-- returns machine and machine arch from arch string
function freebsd_utils.get_machine_and_machine_arch(arch)
    local m, ma = string.match(arch, "(%w+):(%w+)")
    return m, ma
end

-- returns if the arch string is valid
function freebsd_utils.is_arch_string(arch)
    local m, ma = string.match(arch, "(%w+):(%w+)")
    if m and ma then
        return true
    end
    return false
end

-- returns the machine architecure from machine
function freebsd_utils.get_machine_architecture(m)
    for _, arch_string in ipairs(freebsd_utils.arch_list) do
        local machine, machine_arch = string.match(arch_string, "(%w+):(%w+)")
        if machine == m then
            return machine_arch
        end
    end
    return nil
end

-- returns the machine combo from machine and machine architecture
function freebsd_utils.get_machine_combo(m, ma)
    if m ~= ma then
        return m.."-"..ma
    end
    return m
end

-- returns the flavor from arch string and returns it
function freebsd_utils.find_flavor(arch)
    local m, ma = string.match(arch, "(%w+):(%w+)")
    local flavor = "bootonly.iso"

    -- for arm64, we have GENERICSD images only
    if m == "arm64" then
        flavor = "GENERICSD"
    end
    return flavor
end

-- returns the image filename
function freebsd_utils.get_img_filename(machine_combo, flavor, version)
    local filename ="FreeBSD-"..version.."-RELEASE-"..machine_combo.."-"..flavor
    return filename
end

-- returns the image url
function freebsd_utils.get_img_url(urlbase, m, ma, version)
    local machine_combo = freebsd_utils.get_machine_combo(m, ma)
    local flavor = freebsd_utils.find_flavor(m..":"..ma)
    local img_filename = freebsd_utils.get_img_filename(machine_combo, flavor, version)
    local url = urlbase.."/"..m.."/"..ma.."ISO-IMAGES/"..version.."/"..img_filename..".xz"
    return url
end

-- return rc_conf for the m, ma
function freebsd_utils.get_rc_conf(m, ma)
    -- simple etc/rc
    local rc = [[
#!/bin/sh
sysctl machdep.bootmethod
echo "RC COMMAND RUNNING -- SUCCESS!!!"
halt -p
]]
    return rc
end

-- returns loader.conf for the m, ma
function freebsd_utils.get_loader_conf(m, ma)
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

-- returns fstab file
function freebsd_utils.get_fstab_file(filesystem)
    -- fstab table for different fs
    local fs = filesystem or "ufs"
--# Device        Mountpoint      FStype  Options Dump    Pass#
    local fstab_table = {
        ufs = [[
/dev/ufs/root   /               ufs     rw      1       1
]],
        zfs = [[
/zroot/ROOT/default   /               zfs     rw      1       1
]]
    }
    return fstab_table[fs]
end

function freebsd_utils.get_boot_efi_name(ma)
    -- make a table of machine arch and boot efi name
    local boot_efi_name = {
        amd64 = "bootx64.efi",
        i386 = "bootia32.efi",
        armv7 = "bootarm.efi",
        aarch64 = "bootaa64.efi",
        powerpc = "bootppc64.efi",
        powerpc64 = "bootppc64.efi",
        riscv64 = "bootriscv64.efi",
        powerpc64le = "bootppc64le.efi"
    }
    -- check if invalid machine arch
    return boot_efi_name[ma]
end

function freebsd_utils.get_bios_code_name(ma)
    -- make a table of machine arch and boot efi name
    local bios_code_name = {
        amd64 = "boot1.efi",
        i386 = "boot1.efi",
        armv7 = "boot1.efi",
        aarch64 = "boot1.efi",
        powerpc = "boot1.efi",
        powerpc64 = "boot1.efi",
        riscv64 = "boot1.efi",
        powerpc64le = "boot1.efi"
    }
    -- check if invalid machine arch
    return bios_code_name[ma]
end

function freebsd_utils.get_bios_vars(ma)
    -- make a table of machine arch and boot efi name
    local bios_vars = {
        amd64 = "boot1.efi",
        i386 = "boot1.efi",
        armv7 = "boot1.efi",
        aarch64 = "boot1.efi",
        powerpc = "boot1.efi",
        powerpc64 = "boot1.efi",
        riscv64 = "boot1.efi",
        powerpc64le = "boot1.efi"
    }
    -- check if invalid machine arch
    return bios_vars[ma]
end

function freebsd_utils.get_esp_recipe(esp, src)
    -- -t msdos : fat32 filesystem
    -- -o fat_type=32 : 32 or 64 bit fat file
    -- -o sectors_per_cluster=1 : each cluster will have 1 sector
    -- -s 100m : size of fs to be 100MB
    return "makefs -t msdos -o fat_type=32 -o sectors_per_cluster=1 -o volume_label=EFISYS -s 100m "..esp.." "..src
end
function freebsd_utils.get_fs_recipe(fs_type, fs_file, dir1, dir2)
    -- -t ffs : fast file system
    -- -B little : little_endian format
    -- -s 200m : size of fs to be created 200MB
    -- -o label=root : specifies the label as root
    -- copies over content of the dir1, dir2 into the fs indicated
    local cmd = ""
    if fs_type == "zfs" then
        local size = "200m"
        local poolname = "tank"
        local bootfs = "tank"
        local rootpath = "/"
        cmd = string.format("makefs -t zfs -s %s -o poolname=%s -o bootfs=%s -o rootpath=%s %s %s %s",size, poolname, bootfs, rootpath, fs_file, dir1, dir2)
        print(cmd)
    else
        cmd = "makefs -t ffs -B little -s 200m -o label=root "..fs_file.." "..dir1.." "..dir2
    end
    return cmd
end
function freebsd_utils.get_img_command(esp, fs_type, fs_file, img, bi)
    -- if fs == "zfs" then
    --     return "mkimg -s gpt -p efi:="..esp.." -p freebsd-zfs:="..fs.." -o "..img
    -- elseif fs == "ufs" then
    --     return "mkimg -s gpt -p efi:="..esp.." -p freebsd-ufs:="..fs.." -o "..img
    -- end
    local cmd = ""
    cmd = string.format("mkimg -s %s -p efi:=%s -p freebsd-%s:=%s -o %s", bi, esp, fs_type, fs_file, img)
    return cmd
end
-- returns the qemu script for the m, ma
function freebsd_utils.get_qemu_script(m, ma, img, bios_code, bios_vars, raw_disk)
    local qemu_bin = "/usr/local/bin/qemu-system-x86_64"
    local mc = freebsd_utils.get_machine_combo(m, ma)

    local script_file = ""
    -- set script file
    if ma == "amd64" then
      script_file = string.format([[%s -nographic -m 512M \
      -drive file=%s,if=none,id=drive0,cache=writeback,format=raw \
      -device virtio-blk,drive=drive0,bootindex=0 \
      -drive file=%s,format=raw,if=pflash \
      -monitor telnet::4444,server,nowait \
      -serial stdio $*]],
      qemu_bin, img, bios_code, bios_vars)

    elseif ma == "aarch64" then
      local raw = build.IMAGE_DIR.."/"..mc.."/nvme-test-empty.raw"
        -- make a raw file
      script_file = string.format([[%s -nographic -machine virt,gic-version=3 -m 512M \
      -cpu cortex-a57 -drive file=%s,if=none,id=drive0,cache=writeback -smp 4 \
      -device virtio-blk,drive=drive0,bootindex=0 \
      -drive file=%s,format=raw,if=pflash \
      -drive file=%s,format=raw,if=pflash \
      -drive file=%s,if=none,id=drive1,cache=writeback,format=raw \
      -device nvme,serial=deadbeef,drive=drive1 \
      -monitor telnet::4444,server,nowait \
      -serial stdio $*]],
      qemu_bin, img, bios_code, bios_vars, raw)

    end

    return script_file
    
end

return freebsd_utils