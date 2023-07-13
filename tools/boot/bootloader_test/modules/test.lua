#!/usr/libexec/flua

--------------------------------------------------------------------------------
--                                import modules
--------------------------------------------------------------------------------
local freebsd_utils = require('modules.freebsd_utils')
local utils         = require('modules.utils')
local logger        = require('modules.logger')

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
local SCRIPT_DIR = STAND_ROOT.."/scripts" -- this is where the scripts are stored by the build script

--------------------------------------------------------------------------------
--                                functions
--------------------------------------------------------------------------------

-- validates the config
function test.validate_bootloader_config(config)
    -- check if the config has the required fields
    local required_fields = {
        "machine",
        "machine_arch"
    }
    -- check if the config has the required fields
    for _, field in ipairs(required_fields) do
        if not config[field] then
            return false, "Config missing field: "..field
        end
    end

    -- check if the script exists
    local machine_combo = freebsd_utils.get_machine_combo(config.machine, config.machine_arch)
    local script = SCRIPT_DIR.."/"..machine_combo.."/freebsd-test.sh"
    if not utils.file_exists(script) then
        return false, "Script "..script.." does not exist"
    end

    -- check if the script is executable
    --[[
    if not utils.is_executable(script) then
        return false, "Script "..script.." is not executable"
    end
    ]]

    return true
end

function test.test_bootloader(config)
    logger.info("Validating bootloader config")
    -- validate the config
    local status, err = test.validate_bootloader_config(config)
    if not status then
        logger.info("Bootloader config is invalid")
        logger.info(err)
        return false, err
    end
    logger.info("Bootloader config is valid")

    local machine = config.machine
    local machine_arch = config.machine_arch
    local machine_combo = freebsd_utils.get_machine_combo(machine, machine_arch)
    local script = SCRIPT_DIR.."/"..machine_combo.."/freebsd-test.sh"

    -- read contents of the script
    logger.info("Reading script contents")
    local cmd = utils.read_file(script)
    logger.debug("Script contents: "..cmd)
    logger.info("Running qemu with script")
    -- TODO: add some loading message : ETA or time elapsed or something and move this to new function
    local cmd_out = utils.capture_execute(cmd, true)
    logger.info("qemu run complete")
    logger.debug("qemu run output: "..cmd_out)

    logger.info("Checking if bootloader test passed")
    -- check if cmd_out has the string that we wrote in rc script
    -- match for "RC COMMAND RUNNING -- SUCCESS!!!"
    if string.find(cmd_out, "RC COMMAND RUNNING %-%- SUCCESS!!!") then
        return true, "Bootloader test passed."
    else
        return false, "Bootloader test failed."
    end
end

-- default values
return test

--------------------------------------------------------------------------------
--                                end
--------------------------------------------------------------------------------