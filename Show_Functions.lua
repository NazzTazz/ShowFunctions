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

-- CONFIGURATION

ShowConfig = ShowConfig or {}

-- READ AT YOUR OWN RISK

local Show, User, Gui = gma.show, gma.user, gma.gui;

local IMMEDIATE, BUFFERED = 0, 1

local CommandBuffer = {}
local CommandMode = IMMEDIATE


-- 	Executes a GMA2 Command
-- 	Params use string.format order
function Cmd(...)
	if CommandMode == IMMEDIATE then
		gma.cmd(string.format(...))
	elseif CommandMode == BUFFERED then
		CommandBuffer[#CommandBuffer+1] = string.format(...)
	end
end

-- 	Runs all awaiting commands in CommandBuffer
--	Clears CommandBuffer
local function CmdFlushBuffer()
	gma.cmd(table.concat(CommandBuffer, '; '))
	CommandBuffer = {}
end

--	Print a debug line in terminal
--	Params use string.format order 
function Debug(...)
	if (true) then
		gma.echo(string.format(...))
	end
end

--	Checks if a slot is Empty
--	@param (string) object_type (Effect, Image, Sequence, Preset...)
-- 	@param (string) id (1, "MyGroup", 4.2...)
--	@return true if slot is empty, false otherwise
local function checkSlot(object_type, id)
	return Show.getobj.handle(string.format("%s %s", object_type, id)) == nil
end

--	Checks if (length) (object_types) are empty starting from id (first_id)
local function checkRange(object_type, first_id, length)

	local range_is_empty = true
	local next_free_slot = first_id 
	Debug ("-> Testing from %d", next_free_slot)
	for id = first_id, first_id + length do
	
		if checkSlot(object_type, id) == false then
			range_is_empty = false
			next_free_slot = id + 1
			Debug ("-> Found 1 %s on slot #%d !!!", object_type, id)
			break 
		end
	
	end 

	return range_is_empty, next_free_slot
end 


-- 	Returns the first id of (length) free objects in a row
--	@param (string) object_type "Image, Sequence, Macro..."
--	@param (int) first_id first id used to search
-- 	@param (int) length amount of free objects to find
local function findFreeRange(object_type, first_id, length)

	Debug ("Seeking a range of %d %s(s) starting from %d", length, object_type, first_id)
	local next_free_slot = first_id
	local range_is_empty = false
	
	while (not range_is_empty) do
		
		range_is_empty, next_free_slot = checkRange(object_type, next_free_slot, length)
		
	end
	Debug ("== Found %d free %s(s) slot(s) from %d to %d", length, object_type, next_free_slot, next_free_slot+length)
	return next_free_slot 

end

--	Creates an executor from given group/object
--	@param (string) group: Group on which will be applied the object
--	@param (string) object_name: Object to apply on the group (e.g: Effect 1, Preset 0.1 ...)
--	@param (string)	label: Label of the executor (or cue) (optionnal)
--	@param (string) exec: Executor to write to (e.g: 5, 100.101 ...)
--  @param (int) cue: Cue used when storing (optionnal: default=1)
--	@param (string) cmd: Command to inject on the Cue (optionnal)
--	@param (string) func: Function to assign on the executor (e.g: Go, Goto, Flash, Temp ...) (optionnal)
--	@param (float) fade: Fade time applied to the cue (optionnal)
--	@param (float) offtime: Executor offtime (optionnal) 
function executorFromObject(group, object_name, label, exec, cue, cmd, func, fade, offtime)

	local cue_chunk = '';
	
	if cue then
		cue_chunk = 'Cue ' .. cue
	end
	
	Cmd("Group %s; At %s; Store %s Exec %s /o; ClearAll", group, object_name, cue_chunk, exec)
	
	CommandMode = BUFFERED
	
	if label then
		Cmd('Label %s Exec %s "%s"', cue_chunk, exec, label)
	end
	
	if cmd then
		Cmd('Assign %s Exec %s /cmd="%s"', cue_chunk, exec, cmd)
	end
	
	if func then
		Cmd ("Assign %s Exec %s", func, exec)
	end 
	
	if fade then
		Cmd ("Assign Fade %d Exec %s", fade, cue_chunk, exec)
	end 
	
	if offtime then
		Cmd ("Assign %s Exec %s /offtime=%d", cue_chunk, exec, offtime)
	end 
	
	if appearance then
		Cmd("Appearance %s Exec %s %s", cue_chunk, exec, appearance)
	end
	
	CmdFlushBuffer()
	
	CommandMode = IMMEDIATE
	
end 

--  Ensure Images that will be used in a Layout exist, thus preventing broken links
--	@param (int) guiImage: Image used in Layout
--	@param (int) activeImage: source Image used in active state
--	@param (int) inactiveImage: source Image used in inactive state
--	@param (int) placeholder: source Image used as placeholder if absent from image pool 
local function prepareLayoutImages(guiImage, activeImage, inactiveImage, placeholder)
	if (checkSlot('Image', guiImage)) then Cmd("Copy Image %d At %d", placeholder, guiImage) end
	if (checkSlot('Image', activeImage)) then Cmd("Copy Image %d At %d", placeholder, activeImage) end
	if (checkSlot('Image', inactiveImage)) then Cmd("Copy Image %d At %d", placeholder, inactiveImage) end
end

local function ObjectName(object_type, prefix, id)
	return string.format("%s %s%s%d", object_type, prefix or '', prefix and '.' or '', id)
end

function createPicker(object_type, prefix, config, colorize, pickerVarsPrefix, group_offset)

	group_offset = group_offset or 0
    local exec = 101
	local row = 1
	local content_width = (config.LastId - config.FirstId)
	local picker_width = math.ceil(content_width / 5) * 5
	
	if picker_width > 15 then return nil end -- no pickers with more than 15 tiles per row allowed.
											 -- FIXME return proper error with error description
											 
	local row_padding = picker_width - content_width
	local Layout = {}
	
	if config.UseLayout then
	
		local groups = config.LastGroup - config.FirstGroup
		local used_macros = 16 * groups -- Allow 16 Macros per group so Macro Pool View looks nice. I know.
		config.FirstMacroId = findFreeRange('Macro', config.FirstMacro, used_macros)	
	end 
	
	for group = config.FirstGroup, config.LastGroup do
		local group_label = Show.getobj.label(Show.getobj.handle(string.format("Group %d", group))) or 'Group'
		Cmd("Clear ; Group %d", group)
		
		local group_fixtures_count = tonumber(Show.getvar("SELECTEDFIXTURESCOUNT"))
		
		local col = 1
		
		for id = config.FirstId, config.LastId do
			
			local object_name = ObjectName(object_type, prefix, id + (group_offset * (row-1)))
			local macro = ''
									
			Cmd("ClearAll; Selfix %s; If Group %d", object_name, group)
			
			local fixtures_count = tonumber(Show.getvar("SELECTEDFIXTURESCOUNT"))

			if (group_fixtures_count > 0) and (fixtures_count > 0) then
			
				local cmd = nil
				if pickerVarsPrefix then
					cmd = string.format("SetVar $_%s_G%d %d", pickerVarsPrefix, row, exec)
				end
				
				local object_label = Show.getobj.label(Show.getobj.handle(object_name))
				
				executorFromObject(group, object_name, object_label or '--', config.Page .. '.' .. exec, 1, cmd, "go")
				Cmd('Label Executor %d.%d "%s"', config.Page, exec, group_label)
				
				if colorize then
					if type(colorize) == 'table' and #colorize == 3 then
						cmd = string.format("/r=%d /g=%d /b=%d", colorize[1], colorize[2], colorize[3])
					elseif type(colorize) == 'table' then
						-- TBD
					elseif colorize == 'Group' then
						cmd = string.format("At Group %d", group)
					else
						cmd = string.format("At %s", object_name)
					end 
					Cmd("Appearance Exec %d.%d %s", config.Page, exec, cmd) 
				end
				
				if config.UseLayout then
					
					local macro_id = config.FirstMacroId + (row-1)*16 + col
					local inactiveImage = config.FirstInactiveImage + col + (row-1)*group_offset - 1
					local activeImage = config.FirstActiveImage + col + (row-1)*group_offset - 1
					
					prepareLayoutImages(macro_id, activeImage, inactiveImage, 16)
					
					local macro_cmd = string.format("Go Executor %d.%d ; Copy Image %d Thru %d At %d /m; Copy Image %d At %d /m", config.Page, exec, config.FirstInactiveImage, config.FirstInactiveImage + 14, config.FirstMacroId + (row-1)*16 +1, activeImage, macro_id)
					
					Cmd('Store Macro %d', macro_id)
					Cmd('Store Macro 1.%d.1 "%s"', macro_id, macro_cmd)
					
					config.LayoutXOffset = config.LayoutXOffset or 0
					config.LayoutYOffset = config.LayoutYOffset or 0					
					
					Layout[#Layout+1] = layout_add_macro(macro_id, config.LayoutXOffset + col*1.1 - 1 , config.LayoutYOffset + row*1.1 - 1, macro_id)
					
				end 
			end 
			exec = exec + 1 
			col = col + 1
			Cmd("ClearAll")
		end 
		exec = exec + row_padding - 1
		row = row + 1
		Cmd("ClearAll")
	end 
	
	Cmd("ClearAll")
	
	if config.UseLayout then 
		layout_create(config.Layout, Layout)
	end 
end 

function createSpecials(config)
	config = config or ShowConfig.Specials
	
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

function layout_add_macro(macro, xpos, ypos, image, image_rotate)
    local element 
    if image then
		local rot = ''
		if image_rotate then
			rot = ' image_rotation="180°"'
		end
        element = '<LayoutCObject font_size="Small" center_x="'..xpos..'" center_y="'..ypos..'" size_h="1" size_w="1" background_color="3c3c3c" border_color="5a5a5a" icon="None" function_type="Simple" select_group="1" image_size="Fit"'..rot..'><image name="Foo"><No>8</No><No>'..image..'</No></image><CObject name="Foo"><No>13</No><No>1</No><No>'..macro..'</No></CObject></LayoutCObject>'
    else
        element = '<LayoutCObject font_size="Small" center_x="'..xpos..'" center_y="'..ypos..'" size_h="1" size_w="1" background_color="3c3c3c" border_color="5a5a5a" icon="None" show_id="1" show_name="1" show_type="1" function_type="Pool icon" select_group="1"><image /><CObject name="Foo"><No>13</No><No>1</No><No>'..macro..'</No></CObject></LayoutCObject>'
    end
    
    return element 
end

function layout_create(layout_id, objects)

    local buffer = '<?xml version="1.0" encoding="utf-8"?><MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.9.60/MA.xsd" major_vers="3" minor_vers="9" stream_vers="60"><Info datetime="2024-05-12T15:57:58" showfile="ca marche" />' .. "\r\n" ..
    '<Group index="0" name="Empty"><LayoutData index="0" marker_visible="true" snap_always_active="true" background_color="000000" visible_grid_h="1" visible_grid_w="0" snap_grid_h="0.5" snap_grid_w="0.5" default_gauge="Filled &amp; Symbol" subfixture_view_mode="DMX Layer"><CObjects>'
    
    buffer = buffer .. table.concat(objects)
    
    buffer = buffer .. '</CObjects></LayoutData></Group></MA>'
    
    local hTemplate = io.open(gma.show.getvar('PATH') .. "/importexport/layout_test.xml", "w")
    
    hTemplate:write(buffer)
    
    hTemplate:close()
    
    gma.cmd('Import "layout_test.xml" at layout '..layout_id..' /nc')
    
    os.remove(gma.show.getvar('PATH') .. "/importexport/layout_test.xml")
end

function temp_goboPicker()

--
--  TEMPORARY GOBO PICKER - do NOT USE IN PRODUCTION - test show hardvalues everywhere !!
--  seriously, do yourself a favor, don't try using this ;)

	local layout = {}
	local row = 0
	for group = 12, 15 do
	
		Cmd("ClearAll")
		
		local col = 0
		
		for col = 0 , 6 do
		
			preset = 97 + row*11 + col
			first_inactive_image = 656 + row*32
			inactive_image = first_inactive_image + col
			first_active_image = 640 + row*32
			active_image = first_active_image + col
			first_gui_image = 1809 + row*16
			gui_image = first_gui_image + col
			local place_holder = 547
			
			macro_id = 1808 + row*16 + col

			page = 102
			exec = 101 + row
			cue = col + 1
			
			Cmd('Group %d; At Preset 3.%d; Store Cue %d Exec %d.%d Fade 0 "%s" /o', group, preset, cue, page, exec, "Gobo " .. cue)
			Cmd('Label Exec %d.%d "%s"', page, exec, "Gobos")
			Cmd('Store Macro %d "%s"', macro_id, string.format("GOBO %d GROUP %d", col, row))
			Cmd('Store Macro 1.%d.1 "Goto Cue %d Exec %d.%d"', macro_id, cue, page, exec)
			Cmd('Store Macro 1.%d.2 "Copy Image %d Thru %d At %d /o /nc"', 
				macro_id, first_inactive_image, first_inactive_image + 14, first_gui_image)
			Cmd('Store Macro 1.%d.3 "Copy Image %d At %d /o /nc"', macro_id, active_image, gui_image)
			layout[#layout+1] = layout_add_macro(macro_id, col*1.1, row*1.1, gui_image)
			Cmd("Copy Image %d at %d /o /nc", place_holder, gui_image)
			Cmd('Label Image %d "%s"', inactive_image, string.format("R %d G%d I", row, col))
			Cmd('Label Image %d "%s"', active_image, string.format("R %d G%d A", row, col))
			Cmd('Label Image %d "%s"', gui_image, string.format("R %d G%d G", row, col))
		end
		row = row + 1
	end
	layout_create(17, layout)
end



function getFixtures(group)

	local objectType
	local xml = {} 
	local fixtures = {} 
	local file = {}

	file.name =	'tmp_fixtures_list'
	file.path =	gma.show.getvar('PATH')..'/'..'importexport'..'/'
	
	file.filename = function(self)
	    return self.name .. '.xml' 
	end
	
	file.getpath = function(self)
	    return self.path .. self:filename()
	end
	
	CommandMode = IMMEDIATE

	Cmd('SelectDrive 1')
	Cmd('Export Group %d "%s"', group, file:filename())

	for line in io.lines(file:getpath()) do
		xml[#xml + 1] = line
	end
	
	os.remove(file:getpath()) 
		
	for i = 1, #xml do
	
		if (string.find(xml[i],'Subfixture fix_id') or string.find(xml[i],'Subfixture cha_id')) then

			if string.find(xml[i],'fix_id') then
				objectType = 'Fixture '
			elseif string.find(xml[i],'cha_id') then
				objectType = 'Channel '
			end

			local indices = {string.find(xml[i],'\"%d+\"')}
			indices[1], indices[2] = indices[1] + 1, indices [2] - 1

			fixtures[#fixtures+1] = string.format("%s %s", objectType, string.sub(xml[i],indices[1], indices[2]))

		end
	end
	return fixtures
end

ShowConfig.Loaded = true