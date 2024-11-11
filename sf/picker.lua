-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Picker module 

local base = _G
local Tools = require("showfunctions.tools")
local Obj = require("showfunctions.obj")
local Executor = require("showfunctions.executor")
local Layout = require("showfunctions.layout")
local string = require("string")
local table = require("table")
local _M = {};

local Picker = { 
	Layout = {
		RegionWidth = 0,
		RegionHeight = 0
	},
	Defaults = {
		Executors = {
			Start = 101
		},
		Ranges = {
			GroupOffset = 0
		},
		Layout = {
			Macros = {
				Start = 1000,
				Overwrite = false
			},
			Images = {
				GroupOffset = 0
			},
			ButtonGeometry = {
				Width = 1,
				Height = 1,
				XSpacing = 0.1,
				YSpacing = 0.1
			},
			XOffset = 0,
			YOffset = 0
		}
	}
}

_M = Picker 

function Picker.prepareLayoutImages(guiImage, activeImage, inactiveImage, placeholder)
    if (Tools.SlotIsEmpty('Image', activeImage)) then Cmd("Copy Image %d At %d", placeholder, activeImage) end
    if (Tools.SlotIsEmpty('Image', inactiveImage)) then Cmd("Copy Image %d At %d", placeholder, inactiveImage) end
	if (Tools.SlotIsEmpty('Image', guiImage)) then Cmd("Copy Image %d At %d", inactiveImage, guiImage) end
end

function Picker:CreateLayoutItem(Row, col, Exec, PickerWidth)
	local macro_offset = (Row-1)*16 + col
	local image_offset = (Row-1)*(self.Layout.Images.GroupOffset or 0) + col - 1
	local macro_id = FirstMacroId + macro_offset
	local activeImage = self.Layout.Images.Active + image_offset
	local inactiveImage = self.Layout.Images.Inactive + image_offset
	local image = {}
	local geometry = {}
	local inactiveImageList = string.format("%d Thru %d", self.Layout.Images.Inactive, self.Layout.Images.Inactive + PickerWidth - 1)
	local firstImageOfRow = self.Layout.Images.Picker + (Row - 1) * 16 + 1

	Picker.prepareLayoutImages(macro_id, activeImage, inactiveImage, Properties.Layout.Images.Placeholder)

	local macro_cmd = string.format(
		"Go Executor %d.%d ; Copy Image %s At %d /o; Copy Image %d At %d /o", 
		self.Executors.Page, 
		Exec, 
		inactiveImageList, 
		firstImageOfRow, 
		activeImage, 
		macro_id)
	
	Cmd('Store Macro %d', macro_id)
	Cmd('Label Macro %d "%s"', macro_id, string.format("%s%sR%dC%d", self.VarsPrefix or '', self.VarsPrefix and '-' or '', Row, col))
	Cmd('Store Macro 1.%d.1 "%s"', macro_id, macro_cmd)
	
	local XOffset = self.Layout.XOffset or 0
	local YOffset = self.Layout.YOffset or 0					
	
	image.id = macro_id -- FIXME A FAIRE ALLOCATION IMAGES
	Debug("Grabbing name of Image %d", image.id)
	image.label = Obj:New("Image "..image.id):Label()
	
	for _, rot in pairs({'90', '180', '270'}) do
		if string.sub(image.label, 0-string.len(rot)) == rot then
			image.rotate = rot
		end
	end
	
	for k, v in pairs(Picker.Defaults.ButtonGeometry) do 
		geometry[k] = self.Layout.ButtonGeometry and self.Layout.ButtonGeometry[k] or v
	end
	
	geometry.x = (col - 1) * (geometry.Width + geometry.XSpacing) + XOffset 
	geometry.y = (Row - 1) * (geometry.Height + geometry.YSpacing) + YOffset
	
	self._Layout:addMacro(macro_id, geometry, image)
end

function Picker:New(Properties)
	if not Properties or not Properties.Ranges or not Properties.Executors then
		return nil, "Invalid properties provided"
	end 	
    local o = setmetatable({}, { __index = self })    
    for k, v in pairs(Properties) do
        o[k] = v
    end	
	return o
end

function Picker:Generate()
	local ObjectGroupOffset = self.Ranges.GroupOffset or Picker.Defaults.Ranges.GroupOffset	
    local Exec = self.Executors.Start or Picker.Defaults.Executors.Start	
	local Groups = Obj.List(self.Ranges.Groups, "Group")
	local Objects = Obj.List(self.Ranges.Presets, "Preset")	
	local ContentWidth = #Objects
	local PickerWidth = math.min(15, math.ceil(#Objects / 5) * 5)

	if ContentWidth > 15 then return nil, "Max Picker Width exceeded" end
											 
	local RowPadding = PickerWidth - ContentWidth
	
	local FirstMacroId = nil 
	local used_macros
	
	if self.Layout and self.Layout.Id then			
		used_macros = 16 * #Groups
		FirstMacroId = self.Layout.Macros.Overwrite and self.Layout.Macros.Start or Tools.FindFreeRange('Macro', self.Layout.Macros.Start, used_macros)
		self._Layout = Layout:New()
	end 
	
	local Row = 1
	for _, group in pairs(Groups) do	
		local g = sf.Obj:New(group)		
		Cmd("Clear ; %s", g.Name())		
		local group_fixtures_count = tonumber(Show.getvar("SELECTEDFIXTURESCOUNT"))	
		
		local col = 1		
		for _, obj in pairs(Objects) do			
			local obj = Obj:New(obj)
			-- Translate Object id - useful for different gobo sets across groups
			obj.Id = obj.Id + (ObjectGroupOffset * (Row - 1))		
			local macro = ''									
			Cmd("ClearAll; Selfix %s; If %s", obj:Name(), group)			
			local fixtures_count = tonumber(Show.getvar("SELECTEDFIXTURESCOUNT"))

			if (group_fixtures_count > 0) and (fixtures_count > 0) then			
				local cmd = self.VarsPrefix and string.format("SetVar $_%s_G%d %d", self.VarsPrefix, Row, Exec)				
				local opts = {
					label = obj:Label(),
					exec = self.Executors.Page ..'.'.. Exec,
					func = "Go"
				}
				if cmd then opts.cmd = cmd end
				
				local c = self.Executors.Colorize
				if c then
					if type(c) == 'table' and #c == 3 then
						opts.appearance = string.format("/r=%d /g=%d /b=%d", c[1], c[2], c[3])
					elseif c == 'Group' then
						opts.appearance = string.format("At %s", group)
					else
						opts.appearance = string.format("At %s", obj)
					end 
				end
				
				local e = Executor:FromObject(group, object_name, opts)

				Cmd('Label Executor %d.%d "%s"', self.Executors.Page, Exec, g:Label())
				
				if self.Layout and self.Layout.Id then
					self:CreateLayoutItem(Row, col, Exec, PickerWidth)
				end 
			end 
			Exec = Exec + 1 
			col = col + 1
			Cmd("ClearAll")
		end 
		Exec = Exec + RowPadding
		Row = Row + 1
		Cmd("ClearAll")
	end 
	Cmd("ClearAll")
	if self.Layout and self.Layout.Id then 
		self._Layout:Store(self.Layout.Id)
	end 
	return self
end 

return _M


-- Create an Executor matrix to be used in ActionButtons widgets
--[[
local myPicker = {
	Method = "Store",				-- "Store", "Copy", "Store+Copy"
	Label = "My Picker",			-- Label used both for Page name and Layout header (if applicable)
	VarsPrefix = "MP",				-- Variable name seed for Picker-Recall Macros ( $_{VarsPrefix}_G{Row} = Page.Exec )	
	Ranges = {
		Groups = "1 Thru 5",		--
		Objects = "4.1 Thru 4.10"	--
		GroupOffset = 0				--	Offset added to Objects range after processing each group
	},	
	Executors = {					
		Page = 101,					--	Picker Page
		Start = 101,				-- 	First Executor 
		Colorize = "Preset"			--	Copy color from: Preset, Effect, Group, { R, G, B }
	},	
	Layout = {
		Id = 150,					--	Layout id for this picker
		Header = "Line",			--	Picker header: nil, "Line", "Rectangle"		
		ButtonGeometry = {			
			Height = 1,				
			Width = 1,
			XSpacing = 0.1,
			YSpacing = 0.1
		},		
		Macros = {
			Start = 1000,
			Overwrite = true		--	If false, SF will seek a continuous range of empty macros starting from Macros.Start
		},		
		Images = {
			Active = 1,				--	First active image used for Buttons
			Inactive = 17,			-- 	First inactive image used for Buttons 
			Picker = 1000,			--  First picker image used for Buttons
			Generate = nil,			--	Delegate function used to generate Picker images (Not implemented yet)
			GroupOffset = 32		--	Offset images per group (Useful for gobo pickers)
		},		
		XOffset = 0,				-- Global layout X translation
		YOffset = 0,				-- Global layout Y translation 
		RegionHeight = nil,			-- Whole picker width (calculated)
		RegionWidth = nil			-- Whole picker height (calculated)
	}
}
]]--
