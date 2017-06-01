-- These functions are lifted directly from awesome 4.1
-- gears/table.lua

-- gears.table

local rtable = table
local gtable = {}

--- Join all tables given as parameters.
-- This will iterate all tables and insert all their keys into a new table.
-- @class function
-- @name join
-- @param args A list of tables to join
-- @return A new table containing all keys from the arguments.
function gtable.join(...)
    local ret = {}
    for _, t in pairs({...}) do
        if t then
            for k, v in pairs(t) do
                if type(k) == "number" then
                    rtable.insert(ret, v)
                else
                    ret[k] = v
                end
            end
        end
    end
    return ret
end

return gtable
