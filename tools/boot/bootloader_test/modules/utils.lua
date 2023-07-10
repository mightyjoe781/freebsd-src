#!/usr/libexec/flua

-- Use utils.lua as a library to import functions

local utils = { _version = "0.1.0" }
local posix = require('posix')

-- generate regex from args
function utils.generate_regex(arch, filesystem, interface, encryption)
    -- any of the args is not passed, use '*' for that arg
    if arch == nil then
        arch = '*'
    end
    if filesystem == nil then
        filesystem = '*'
    end
    if interface == nil then
        interface = '*'
    end
    if encryption == nil then
        encryption = '*'
    end
    return arch .. '-' .. filesystem .. '-' .. interface .. '-' .. encryption
end

-- remove duplicates from a table
function utils.remove_duplicates(t)
    local hash = {}
    local res = {}
    for _, v in ipairs(t) do
        if not hash[v] then
            res[#res+1] = v
            hash[v] = true
        end
    end
    return res
end

-- load a data file
function utils.load_data_file(file)
    local f = io.open(file, "rb")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

-- print a table in a pretty way
function utils.print_table(t)
    for k, v in pairs(t) do
        print(k, v)
    end
end

-- print a complex table in a pretty way
function utils.tprint (tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            utils.tprint(v, indent+1)
        elseif type(v) == 'boolean' then
            print(formatting .. tostring(v))		
        else
            print(formatting .. v)
        end
    end
end

-- check if a table contains a value
function utils.table_contains(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end
    return false
end


-- take intersection of two tables
function utils.intersect_table(a, b)
    local res = {}
    for _, v in ipairs(a) do
        if utils.table_contains(b, v) then
            table.insert(res, v)
        end
    end
    return res
end

-- take union of two tables
function utils.union_table(a, b)
    local res = {}
    for _, v in ipairs(a) do
        table.insert(res, v)
    end
    for _, v in ipairs(b) do
        if not utils.table_contains(res, v) then
            table.insert(res, v)
        end
    end
    return res
end

-- subtract table b from table a, and return the result
-- function utils.subtract_table(a, b)
--     -- A U B - B = A - B
--     return utils.subtract_table(utils.union_table(a, b), b)
-- end

-- subtract table b from table a Alternate implementation
-- faster then the above implementation, and also probably more readable and correct
function utils.subtract_table(a, b)
    local res = {}
    for _, v in ipairs(a) do
        if not utils.table_contains(b, v) then
            table.insert(res, v)
        end
    end
    return res
end

-- check if a file already exists
function utils.file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
end

-- check if a directory already exists
function utils.dir_exists(dir)
    local ok, err, code = os.rename(dir, dir)
    if not ok then
        if code == 13 then
            -- Permission denied, but it exists
            return true
        end
    end
    return ok, err
end
-- check if file is a valid lua file
function utils.is_valid_lua_file(file)
    local f = io.open(file, "rb")
    if not f then return false end
    local content = f:read("*all")
    f:close()
    local status, err = load(content)
    if status then
        return true
    else
        return false
    end
end

-- this doesnt work
-- local SRCTOP = os.execute("make -V SRCTOP")
-- capture function for fixing make -V variable spawns new shell
function utils.capture_execute(cmd, raw)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    if raw then return s end
        s = string.gsub(s, '^%s+', '')
        s = string.gsub(s, '%s+$', '')
        s = string.gsub(s, '[\n\r]+', ' ')
    return s
end

-- utility function to write a file and handle all lua io.open() weirdness
function utils.write_data_to_file(file, data)
    local f = io.open(file, "w")
    -- check if file is even open
    if f == nil then
        return "Failed to open file "..file
    else
      f:write(data)
      f:close()
    end
end

-- Try to avoid executing shell commands in lua, but this is the only way to get the some work done :(

-- utils die function
function utils.die(msg)
    print(msg)
    os.exit(1)
end

-- utils.execute()
function utils.execute(cmd)
    -- print("Executing: "..cmd)
    local _,msg,ret = os.execute(cmd)
    if ret ~= 0 then
        print(msg)
        utils.die("Failed to execute "..cmd)
    end
end

function utils.fetch_file(url, file)
    utils.execute("fetch -o "..file.." "..url)
end

-- get the current working directory
function utils.get_cwd()
    return utils.capture_execute("pwd")
end

-- sleep for n seconds
function utils.sleep(time)
    local start = os.clock()
    while os.clock() - start <= time do end
end

-- timeout execute a command
function utils.sleepy_execute(cmd, timeout)
    local pid = utils.execute(cmd)
    utils.sleep(timeout)
    return pid
end

-- check if a process is running
function utils.is_process_running(pid)
    local _,msg,ret = os.execute("kill -0 "..pid)
    if ret == 0 then
        return true
    else
        return false
    end
end

-- read file contents
function utils.read_file(file)
    local f = io.open(file, "rb")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end
return utils