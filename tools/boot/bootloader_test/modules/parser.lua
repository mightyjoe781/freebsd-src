#!/usr/libexec/flua


local parser = { _version = "0.1.0" }
local utils = require('modules.utils')

-- load the data file for all possible configurations
function parser.get_all_configurations(file)
    local data = utils.load_data_file(file)
    if not data then return nil end
    local configurations = load(data)()
    return configurations
end

return parser