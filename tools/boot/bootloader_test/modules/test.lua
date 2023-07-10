#!/usr/libexec/flua

--------------------------------------------------------------------------------
--                                import modules
--------------------------------------------------------------------------------
local utils = require('modules.utils')
local posix = require('posix')
local parser = require('modules.parser')
local zfs = require('modules.zfs')
local ufs = require('modules.ufs')
local build = require('modules.build')

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
local HOME = os.getenv("HOME")
local QEMU_BIN = "/usr/local/bin/qemu-system-x86_64"

local STAND_ROOT = HOME.."/stand-test-root"
local SRCTOP = utils.capture_execute("make -V SRCTOP", false)
SCRIPT_DIR = build.SCRIPT_DIR or STAND_ROOT.."/scripts"

--------------------------------------------------------------------------------
--                                functions
--------------------------------------------------------------------------------

-- validates the config
function test.validate_bootloader_config(config)

end

-- runs the bootloader test
function test.run_bootloader_config(config)
    -- return the status of running the shell script in the config
    -- but we attach a time to kill the process if it runs too long 2 minutes
    local script = SCRIPT_DIR.."/"..config.machine_combo.."/freebsd-test.sh"
    -- now try to run the script
    local pid = utils.sleepy_execute(script, 120)
    if utils.is_process_running(pid) then
        posix.kill(pid, posix.SIGKILL)
        return false, "Process "..pid.." timed out"
    else
        return true, "Process "..pid.." exited"
    end
end

function test.test_bootloader(config)
    local script = SCRIPT_DIR.."/"..config.machine_combo.."/freebsd-test.sh"

    local cmd_out = utils.capture_execute(script, false)
    -- check if cmd_out has the string that we wrote in rc script
    -- echo "RC COMMAND RUNNING -- SUCCESS!!!"
    
    if string.find(cmd_out, "RC COMMAND RUNNING -- SUCCESS!!!") then
        return true, "Bootloader test passed"
    else
        return false, "Bootloader test failed"
    end
end





-- default values
return test

--------------------------------------------------------------------------------
--                                end
--------------------------------------------------------------------------------