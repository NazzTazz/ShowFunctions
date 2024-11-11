-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Tools module 

local base = _G
local string = require("string")
local table = require("table")
local _M = {};

-- HELPERS

-- 	Executes a GMA2 Command
-- 	Params use string.format syntax
function Cmd(...)
	gma.cmd(string.format(...))
end

--	Print a debug line in terminal
--	Params use string.format syntax
function Debug(...)
	if (true) then
		gma.echo(string.format(...))
	end
end

function tableToString(tbl, indent)
    if not indent then
        indent = ""
    end

    local result = "{\n"
    local newIndent = indent .. "  "

    for k, v in pairs(tbl) do
        local key
        if type(k) == "string" then
            key = string.format("%s", k)
        else
            key = "[" .. tostring(k) .. "]"
        end

        if type(v) == "table" then
            result = result .. newIndent .. key .. " = " .. tableToString(v, newIndent) .. ",\n"
        elseif type(v) == "string" then
            result = result .. newIndent .. key .. " = " .. string.format("%q", v) .. ",\n"
        else
            result = result .. newIndent .. key .. " = " .. tostring(v) .. ",\n"
        end
    end

    result = result .. indent .. "}"
    return result
end

-- Builds an Object Name String (e.g., Preset 4.1, Fixture 8)
-- @param objectType Type of the object (e.g., Preset, Effect, Fixture...)
-- @param poolId Object's [pool.]id (4.1, 5, 9)
-- @param offset Translate Ids in the same pool
function _M:ObjectName(objectType, poolId, offset) -- legacy
	Debug("Tools:ObjectName() is deprecated")
	return Obj.New{ObjectType=objectType, Id=poolId, offset}:Name()
end

return _M