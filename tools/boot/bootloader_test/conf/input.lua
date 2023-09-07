-- (*) : Required parameter
-- return list of configurations of architectures
return {
    recipe_1 = {
        -- required parameters
        arch  = "amd64:amd64",
        machine_arch = "amd64",
        machine_combo = "amd64",

        -- optional parameters
        FreeBSD_version = "13.0",
        img_flavour = "bootonly.iso",
        img_url = "FreeBSD-13.0-RELEASE-amd64-bootonly.iso",

        --[[
            -- expression for combination for testing
            a compact possible expression later on for blacklisting define as filesystem-partition-encryption
            a function should evaluate common combination expressions and calculate all possibilities 
                -- this is acting like filter
        --]]
        -- regex_combination = {"ufs-gpt-geli","*-*-*","*-*-geli"},
        regex_combination = {"*-*-none"},
        
        -- several overrides
        mtree_override = "",
        makefs_override = "",
        mkimg_override = "",
        qemu_args_overrides = "",
    },
    recipe_2 = {
        arch  = "arm64:aarch64",
        regex_combination = {"*-*-none"},
    },
    recipe_3 = {
        arch = "riscv:riscv64",
        regex_combination = {"*-gpt-none"},
    }
}
