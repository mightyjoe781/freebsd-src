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

-- load input.lua config file which returns a table
local config = require "input"

-- find the number of entries in the config file
print("config file entries: ", #config)
-- load recipe_1 to recipe_n
local n = 0
for k,v in pairs(config) do
    n = n + 1
end
print(n)

-- print the config file, print the table address
print("config file: ", config)