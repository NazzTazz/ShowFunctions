--[[

Free Steroïds for your showfile

(c) 2024 Tristan Buet <tristan.buet@gmail.com>

Check for last version:

https://github.com/NazzTazz/ShowFunctions/tree/main

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program; if not, write to the Free Software Foundation,
Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

]]--

local base = _G

local string = require("string")
local math = require("math")
local table = require("table")

-- PROXIES

Show, User, Gui, Object = gma.show, gma.user, gma.gui, gma.show.getobj;

-- SUB-MODULES AND PACKAGE TABLES

local SF = { _debug = true }
local Tools = require("showfunctions.tools")
local Obj = require("showfunctions.obj")
local Executor = require("showfunctions.executor")
local Layout = require("showfunctions.layout")
local Picker = require("showfunctions.picker")

-- local Bitmap = require("showfunctions.bitmap")

SF.Obj, SF.Picker, SF.Executor, SF.Layout--[[, SF.Bitmap]] = Obj, Picker, Executor, Layout--[[, Bitmap]] --

local _M = SF

-- Random crap that won't exist anymore soon

function _M.createSpecials(config)
	local exec = 101
	local slot = 0

	for group = config.FirstGroup, config.FirstGroup + 14 do

		local special_preset = config.FirstId + slot;
		local temp_preset , flash_preset = special_preset + 15, special_preset + 30

		Cmd("ClearAll")
		Cmd("Group %d", group)
		if (tonumber(Show.getvar("SELECTEDFIXTURESCOUNT")) > 0) then
			Cmd("Group %d; At 0 Fade 0.5; Store Cue 1 Executor %d.%d /o", group, config.Page, exec)
			local skip_cmd = string.format("Clear; Selfix Group %d IfOutput ; [$SELECTEDFIXTURESCOUNT==0] Goto Cue 2 Exec %d.%d", group, config.Page, exec)
			Cmd('Assign Cue 1 Exec %d.%d /cmd="%s"', config.Page, exec, skip_cmd)
			Cmd("ClearAll")
			Cmd("Group %d; At Preset 0.%d Fade 0.8; At Full Fade 0.5 Delay 0.8", group, special_preset)
			Cmd("Store Cue 2 Executor %d.%d /o", config.Page, exec)
			Cmd("Group %d; At Preset 0.%d; At 0 Fade 0.5", group, special_preset)
			Cmd("Store Cue 3 Executor %d.%d /o", config.Page, exec)
			Cmd("Group %d; At 0", group)
			Cmd("Store Cue 4 Executor %d.%d /o", config.Page, exec)
			Cmd("ClearAll")
			Cmd("Store Cue 5 Executor %d.%d /o", config.Page, exec)
			local end_cmd = string.format("Off Executor %d.%d Fade 0.5", config.Page, exec)
			Cmd('Assign Cue 5 Exec %d.%d /cmd="%s"', config.Page, exec, end_cmd)
			Cmd("Assign Cue 2 + 4 + 5 Exec %d.%d /trig=follow", config.Page, exec)
			Cmd("Assign Cue 4 + 5 Fade 0.8 Exec %d.%d", config.Page, exec)
			Cmd('Label Exec %d.%d "%s"', config.Page, exec, Show.getobj.label(Show.getobj.handle("Group "..group)))
			Cmd('Label Cue %d Exec %d.%d "%s"', 1, config.Page, exec, Show.getobj.label(Show.getobj.handle("Preset 0."..special_preset)))
			Cmd('Label Cue %d Exec %d.%d "%s"', 2, config.Page, exec, '--')
			Cmd('Label Cue %d Exec %d.%d "%s"', 3, config.Page, exec, 'OFF')
			Cmd('Label Cue %d Exec %d.%d "%s"', 4, config.Page, exec, "(Rel)")
			Cmd('Label Cue %d Exec %d.%d "%s"', 5, config.Page, exec, "(--)")
			Cmd('Assign Go Exec %d.%d', config.Page, exec)
		end
		exec = exec + 1
		slot = slot + 1
	end
end


return _M