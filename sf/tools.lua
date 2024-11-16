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

function DebugTable(title, tbl)
	if (true) then
		local t = TableToString(tbl)
		local i = 1
		for line in t:gmatch("[^\n]+") do
			Debug("%s%s", i == 1 and title..' ' or '', line)
			i = i +1
		end
	end 
end

function TableToString(tbl, indent)
    if not indent then
        indent = ""
    end

    local str = "{\n"
    local newIndent = indent .. "  "

    for k, v in pairs(tbl) do
        local key
        if type(k) == "string" then
            key = string.format("%s", k)
        else
            key = "[" .. tostring(k) .. "]"
        end

        if type(v) == "table" then
            str = str .. newIndent .. key .. " = " .. TableToString(v, newIndent) .. ",\n"
        elseif type(v) == "string" then
            str = str .. newIndent .. key .. " = " .. string.format("%q", v) .. ",\n"
        else
            str = str .. newIndent .. key .. " = " .. tostring(v) .. ",\n"
        end
    end

    str = str .. indent .. "}"
    return str
end

return _M