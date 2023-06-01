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
]]--

local utils = require 'modules.utils'
-- this script will be run using flua and parse command line options
local getopt = require 'posix.unistd'.getopt
local args = {}

local last_index = 1
for r, optarg, optind in getopt(arg, 'ha:f:i:e:c:bt') do
    if r == '?' then
        return print('unrecognized option', arg[optind-1])
    end
    last_index = optind
    if r == 'h' then
        print '-h      print this help text'
        print '-a ARG  architecture to build and test for'
        print '-f ARG  file-system to use for the image'
        print '-i ARG  booting interface to use for the image'
        print '-e ARG  encryption to use for the image'
        print '-c ARG  configuration file to use for the build and test'
        print '-b      build the bootloader only'
        print '-t      test the bootloader only'
    elseif r == 'a' then
        args.arch = optarg
        print('we were passed', r, optarg)
    elseif r == 'f' then
        args.filesystem = optarg
        print('we were passed', r, optarg)
    elseif r == 'i' then
        args.interface = optarg
        print('we were passed', r, optarg)
    elseif r == 'e' then
        args.encryption = optarg
        print('we were passed', r, optarg)
    elseif r == 'c' then
        args.config = optarg
        print('we were passed', r, optarg)
    end
end

-- generate the config regex from the args : <arch>-<filesystem>-<interface>-<encryption>
-- if any of the args is not passed, use '*' for that arg
print(utils.generate_regex(args.arch, args.filesystem, args.interface, args.encryption))

for i = last_index, #arg do
   print(i, arg[i])
end