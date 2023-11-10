#!/usr/libexec/flua

local parser = { 
    _required_config_keys = {
        "arch",
        "regex_combination"
    },
    _version = "0.1.0" ,
    _name = "parser",
    _description = "A library of functions for parsing the config file",
    _license = "BSD 3-Clause"
}
local combination = require('modules.combination')
local utils = require('modules.utils')
local freebsd_utils = require('modules.freebsd_utils')
local logger = require('modules.logger')

-- a config blueprint for building the bootloader


-- do some validation on the config
local function file_validation(filepath)
    -- * load the data file
    -- check if file exists
    if not utils.file_exists(filepath) then
        return false, "File does not exist"
    end

    -- try to load the data file, validate if it is a lua file
    if not utils.is_valid_lua_file(filepath) then
        return false, "Unable to load config file not a valid lua file"
    end

    -- load file and check if required keys are present
    local configfile = dofile(filepath)
    for k,recipe in pairs(configfile) do
        for _,key in pairs(parser._required_config_keys) do
            if recipe[key] == nil then
                return false, "Required key " .. key .. " is missing from "..k
            end
        end
    end

    -- do recipe validation
    for k,recipe in pairs(configfile) do
        local valid, err = parser.validate_recipe(recipe)
        if not valid then
            return false, "Recipe " .. k .. " is not valid: " .. err
        end
    end

    return true
end


-- add validation related to the config file contents here
function parser.validate_recipe(recipe)
    -- validate if regex_combination is a table and has at least one entry
    -- validate it follows the regex format : *-*-*
    if type(recipe.regex_combination) ~= "table" then
        return false, "regex_combination is not a table"
    end
    if #recipe.regex_combination == 0 then
        return false, "regex_combination is empty"
    end
    for _,regex_combination in pairs(recipe.regex_combination) do
        -- validate if it has format : *-*-*
        local filesystem, interface, encryption = regex_combination:match("([^%-]+)%-([^%-]+)%-([^%-]+)")
        if filesystem == nil or interface == nil or encryption == nil then
            return false, "regex_combination is not in the format *-*-*"
        end

        -- validate if filesystem, interface, encryption is valid
        -- filesytem is not * and is not in the list of valid filesystems

        if filesystem ~= "*" and not combination.is_valid_filesystem(filesystem) then
            return false, "filesystem is not valid"
        end

        -- interface is not * and is not in the list of valid interfaces
        if interface ~= "*" and not combination.is_valid_interface(interface) then
            return false, "interface is not valid"
        end

        -- encryption is not * and is not in the list of valid encryption
        if encryption ~= "*" and not combination.is_valid_encryption(encryption) then
            return false, "encryption is not valid"
        end
    end
    return true
end


-- load the data file for all possible configurations
function parser.get_all_configurations(file, filter_combination)

    -- validate the data file
    local valid, err = file_validation(file)
    if not valid then
        return nil, err
    end

    local configs = {}

    -- load the config file into a table
    -- local configfile = utils.load_data_file(file)
    -- we could add some validation so no one actually executes the config file

    -- TODO: Cleanup this code

    -- load the config file into a table
    local configfile = dofile(file)

    -- for each recipe in the config file generate a config
    for _,recipe in pairs(configfile) do
        -- now we read regex_combination and generate a config for each combination
        local architecture = recipe.arch
        local valid_regex_combinations = {}
        -- print each regex_combination
        for _,regex_string in pairs(recipe.regex_combination) do
            local filesystem, interface, encryption = regex_string:match("([^%-]+)%-([^%-]+)%-([^%-]+)")
            -- print(filesystem, interface, encryption)
            local regex_pattern = architecture.."-"..filesystem.."-"..interface.."-"..encryption
            -- print(regex_pattern)
            local combinations = combination.generate_combinations(regex_pattern)
            for _,comb in pairs(combinations) do
                table.insert(valid_regex_combinations, comb)
            end
        end
        -- remove duplicates from valid_regex_combinations
        valid_regex_combinations = utils.remove_duplicates(valid_regex_combinations)
        -- utils.tprint(valid_regex_combinations)

        -- generate configs for each valid_regex_combinations such that all the recipes are copied
        -- and the regex_combination is replaced with the valid_regex_combination
        for _,regex_combination in pairs(valid_regex_combinations) do
            local _, filesystem, interface, encryption = regex_combination:match("([^%-]+)%-([^%-]+)%-([^%-]+)%-([^%-]+)")
            local config = {
                architecture = architecture,
                filesystem = filesystem,
                interface = interface,
                encryption = encryption,
                combination_expression = regex_combination,
                recipe = recipe
            }
            config = parser.fix_config(config)
            table.insert(configs, config)
        end
        -- print all valid_regex_combinations
    end
    
    -- filter the config file based on the combination
    -- we will generate configs for all possible combination

    -- print all the configs created
    -- utils.tprint(configs)

    -- before returning the configs we need to filter them based on the filter_combination expression
    -- generate a list of configs that match the filter_combination expression
    filter_combination = filter_combination or "*-*-*-*" -- set default filter to universe
    local filtered_combinations = combination.generate_combinations(filter_combination)
    local filtered_configs = {}
    for _,config in pairs(configs) do
        if utils.table_contains(filtered_combinations, config.combination_expression) then
            table.insert(filtered_configs, config)
        end
    end

    -- print all the filtered configs
    -- utils.tprint(filtered_configs)

    -- in each of filtered_config attach a port that is unique
    -- Generate a unique port for each configuration
    local portCounter = 4000  -- Starting port number
    for _, config in ipairs(filtered_configs) do
        config.port = portCounter  -- Assign the unique port to the config
        portCounter = portCounter + 1  -- Increment the port counter for the next configuration
    end
    return filtered_configs
end

-- fix the config file
function parser.fix_config(config)
    -- fix the config
    -- fix if config passes ':' in the architecture
    if freebsd_utils.is_arch_string_valid(config.architecture) then
        local m, ma = freebsd_utils.get_machine_and_machine_arch(config.architecture)
        config.machine = config.machine or m
        config.machine_arch = config.machine_arch or ma
    else
        config.machine = config.architecture or config.machine
        config.machine_arch = config.machine_arch or freebsd_utils.get_machine_architecture(config.machine)
    end
    return config
end

return parser