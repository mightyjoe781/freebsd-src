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
function freebsd_utils.get_fstab_file()
    -- fstab table for different fs
    local fs = "ufs"
--# Device        Mountpoint      FStype  Options Dump    Pass#
    local fstab_table = {
        ufs = [[
/dev/ufs/root   /               ufs     rw      1       1
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

function freebsd_utils.get_qemu_script(m, ma)


end

return freebsd_utils