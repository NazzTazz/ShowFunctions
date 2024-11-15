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

local SF = { 
	_debug = true,
	
	Tools = require("showfunctions.tools"),
	Obj = require("showfunctions.obj"),
	Executor = require("showfunctions.executor"),
	Layout = require("showfunctions.layout"),
	Bitmap = require("showfunctions.bitmap"),
	Picker = require("showfunctions.picker")
}

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


function _M._show_progress(view, index)    

    hView = io.open(gma.show.getvar('PATH').."/importexport/tempview.xml", "w")
    
    local xml = '<?xml version="1.0" encoding="utf-8"?><MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.9.60/MA.xsd" major_vers="3" minor_vers="9" stream_vers="60">    <Info datetime="" showfile="" /><View index="1" name="PROGRESSION" display_mask="32"><BitMap width="96" height="48"><Image>'
    hView:write(xml)    
    
    local progress = math.floor(index * 32/100)
    
    local filled = progress
    local black = 32 - progress
    
    local white_chunk = "fwAA/38AAP9/AAD/"
    local black_chunk = "AAAA/wAAAP8AAAD/"
    
    local scanline = white_chunk:rep(filled) .. black_chunk:rep(black)
    
    hView:write(string.rep(scanline, 48))    
    
    hView:write('</Image></BitMap></View></MA>')
    hView:close()

    gma.cmd('Import "tempview.xml" At View '.. view ..' /nc /o')

    os.remove(gma.show.getvar('PATH').."/importexport/tempview.xml")

end

function _M.import_gobo_image(data, active_index, inactive_index, suffix)
    gma.echo("Importing gobo image to show (UserImages "..active_index.."+"..inactive_index..")")
    
    suffix = suffix or ''


    local active_cache = gma.show.getvar('PATH') .."/importexport/gobo_cache_active_"..suffix..".xml"    
    local inactive_cache = gma.show.getvar('PATH') .."/importexport/gobo_cache_inactive_"..suffix..".xml"    
    
    local hAf = io.open(active_cache, "r")    
    local hIf = io.open(inactive_cache, "r")
        
    if (hAf and hIf) then
        -- Images already generated for this fixture/wheel/gobo 
        -- import from cache
        hAf:close()
        hIf:close()
        gma.echo('-> Reading from cache')
        gma.cmd('Import "gobo_cache_active_'..suffix..'.xml" Image '..active_index..' /o /nc ')
        gma.cmd('Import "gobo_cache_inactive_'..suffix..'.xml" Image '..inactive_index..' /o /nc ')
    else
        gma.echo('No cache for this gobo')
        local raw_thumbnail_data = base64_decode(data)

        local active_gobo = import_thumbnail(raw_thumbnail_data, 64, 64)
        
        if active_gobo == nil then
            gma.gui.confirm("Error", "Couldn't properly import thumbnail data")
            return nil
        end    
        
        local inactive_gobo = new_image(64, 64, active_gobo) -- Deep-copy 3d table    
        
        add_border(active_gobo) -- Adds a white border to selected gobos in gobo picker

        export_bitmap(active_gobo, gma.show.getvar('PATH') .."/images/active"..suffix..".bmp", active_index, 'gobo_cache_active_'..suffix)
        
        darken_image(inactive_gobo, 0.35)

        export_bitmap(inactive_gobo, gma.show.getvar('PATH').."/images/inactive"..suffix..".bmp", inactive_index, 'gobo_cache_inactive_'..suffix)
    end 

end 
return _M