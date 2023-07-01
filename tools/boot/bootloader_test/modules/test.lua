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

-- default values
local test = {
    _version = "0.1.0",
    _name = "test",
    _description = "test module",
    _license = "BSD 3-Clause"
}
QEMU_BIN = "/usr/local/bin/qemu-system-x86_64"

--------------------------------------------------------------------------------
--                                functions
--------------------------------------------------------------------------------

function test.validate_bootloader_config(config)

end

function test.run_bootloader_config(config)
    
end




-- default values
return test

--------------------------------------------------------------------------------
--                                end
--------------------------------------------------------------------------------