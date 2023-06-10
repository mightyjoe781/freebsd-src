#!/usr/libexec/flua
--[[
/*
 * Copyright (c) 2023 Sudhanshu Mohan Kashyap
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * $FreeBSD$
 */
]]--

--[[
    This script will read the input.lua file and parse it to get the configurations
    for the bootloader build and test in various recipes(envs).

    Important steps will be:
    1. Read the input.lua file
    2. Parse the input.lua file
        * Check for required parameters
        * Check for optional parameters
        * Check for overrides
    3. Create a table of configurations
        * parse '*' from predefined list of combinations
        * create a table of all possible combinations (unique)
    4. Drive the build and test process
        * Build source tree for the bootloader for each configuration
        * Create image for each configuration
        * Create mtree for each configuration
        * Create makefs for each configuration
        * Create mkimg for each configurations
        * Create qemu recipe for each configuration
    5. Report the results
        * Build results
        * Test results 
        * Overall results (build and test)
        * Simple matrix of build and test results
        * Detailed matrix of build and test results (only if passed via command line
          option)
    6. Cleanup the build and test environment
    7. Exit with appropriate exit code

    Important notes:
    * The script will be written in Lua, will be run using flua
    * Try to use standard Lua libraries as much as possible like luaposix, optparse,
      etc.
    * The script will be run on FreeBSD 13.0-CURRENT (for now)
    * Keep the script simple and readable
    * Keep the script modular, extensible and maintainable
    * Keep the script as much as possible in pure Lua, avoid using external tools
      like sed, awk, grep, etc.
    * follow the Lua and FreeBSD style guide

    -- Some silly rules to follow(thx pragmatic programming book lol) :P --
    * Use open close principle (OCP)
    * Use single responsibility principle (SRP)
    * Use dependency inversion principle (DIP)
    * Use interface segregation principle (ISP)
    * Use Liskov substitution principle (LSP)
    * Use composition over inheritance principle (COI)
    * Use don't repeat yourself principle (DRY)
    * Use you aren't gonna need it principle (YAGNI)
    * Use keep it simple, stupid principle (KISS)
    * Use separation of concerns principle (SOC)
    * Use convention over configuration principle (COC)
    * Use single level of abstraction principle (SLA)
    * Use principle of least astonishment (POLA)
    * Use least knowledge principle (LKP)
    * Use model view controller principle (MVC)
    * Not able to find more principles, will add more if I find any :P hehe

    -- Some silly questions to ask to Warner --
    * Should we use one script for build and test or two separate scripts?
    * Should we use one script for all architectures or separate scripts for each
      architecture?
    * If we use one script for all architectures, how will we handle the
      architecture specific code?
    * Calendars for biweekly meetings?
    * How to handle the build and test results? (simple matrix print or some other
      way)
      Build x passed / failed
      decide some consistent format
      summary 30/50 passed
      -- logs run store them
    * data-sourcing 
        makeimg : make it smart while building it makes sense according to architectures
    -- think of more in terms of making more atomic libraries like make zfs, ufs and provide
        options for making it work with various arch based on their requirements


]]--

--------------------------------------------------------------------------------
--                                Import modules
--------------------------------------------------------------------------------
local utils         = require 'modules.utils'           -- utility functions
local parser        = require 'modules.parser'          -- parser for input.lua
local logger        = require 'modules.logger'          -- logger for logging
local build         = require 'modules.build'           -- build module
local test          = require 'modules.test'            -- test module
local combination   = require 'modules.combination'     -- combination module
local getopt        = require 'posix.unistd'.getopt     -- getopt module

--------------------------------------------------------------------------------
--                            Define global variables
--------------------------------------------------------------------------------
-- this script will be run using flua and parse command line options

-- set log level to info
logger.level = "debug"

local args = {
    architecture = "*",
    filesystem = "*",
    interface = "*",
    encryption = "*",
    config = "input.lua",
    build = false,
    test = false,
    verbose = false
}

--------------------------------------------------------------------------------
--                              Main function
--------------------------------------------------------------------------------

-- usage function
local function usage()
    print [[
usage: main.lua [-bhtv] [-a ARG] [-f ARG] [-i ARG] [-e ARG] [-c ARG]
    ]]
end

-- man page
local function man_page()
    print [[
NAME
    main.lua - build and test the bootloader
SYNOPSIS
    main.lua [-bhtv] [-a ARG] [-f ARG] [-i ARG] [-e ARG] [-c ARG]
DESCRIPTION
    This script will read the input.lua file and parse it to get the configurations
    for the bootloader build and test in various recipes(envs).
OPTIONS
    -h      print this help text
    -a ARG  architecture to build and test for
    -f ARG  file-system to use for the image
    -i ARG  booting interface to use for the image
    -e ARG  encryption to use for the image
    -c ARG  configuration file to use for the build and test
    -b      build the bootloader only
    -t      test the bootloader only
    -v      verbose output

AUTHOR
    Sudhanshu Mohan Kashyap <
    ]]
end

local last_index = 1
for r, optarg, optind in getopt(arg, 'a:f:i:e:c:btvh') do
    if r == '?' then
        return print('unrecognized option', arg[optind-1])
    end
    last_index = optind
    if r == 'h' then
        -- print usage
        -- usage()
        man_page()
        -- exit with success
        os.exit(0)
    elseif r == 'a' then
        args.arch = optarg
    elseif r == 'f' then
        args.filesystem = optarg
    elseif r == 'i' then
        args.interface = optarg
    elseif r == 'e' then
        args.encryption = optarg
    elseif r == 'c' then
        args.config = optarg
    elseif r == 'b' then
        args.build = true
    elseif r == 't' then
        args.test = true
    elseif r == 'v' then
        logger.level = "debug"
    end
end
--------------------------------------------------------------------------------
--                           Preprocessing and parsing
--------------------------------------------------------------------------------

-- generate the config regex from the args : <arch>-<filesystem>-<interface>-<encryption>
local regex_string = utils.generate_regex(args.arch, args.filesystem, args.interface, args.encryption)
logger.info("Regex Generated from command line args: ", regex_string)

local combinations = combination.generate_combinations(regex_string)
logger.info("Combinations generated from regex: "..#combinations)

-- parse the config file
if args.config == "input.lua" then
    logger.info("Using default config file: input.lua")
else
    logger.info("Using config file: "..args.config)
end

--------------------------------------------------------------------------------
--                        Build and test the bootloader 
--------------------------------------------------------------------------------

-- if build and test both are false, then build and test both
if not args.build and not args.test then
    args.build = true
    args.test = true
end

-- if build is true, then build the bootloader
if args.build then
    logger.info("Building the bootloader")
    -- build the bootloader
end

-- if test is true, then test the bootloader
if args.test then
    logger.info("Testing the bootloader")
    -- test the bootloader
end

-- print the remaining arguments if any
if last_index < #arg then
    logger.info("Remaining arguments: ")
    for i = last_index, #arg do
        print(i, arg[i])
    end
end

os.exit(0)
--------------------------------------------------------------------------------
--                              End of file
--------------------------------------------------------------------------------