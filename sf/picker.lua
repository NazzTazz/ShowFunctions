-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Picker module 

local base = _G
local Obj = require("showfunctions.obj")
local Executor = require("showfunctions.executor")
local Layout = require("showfunctions.layout")
local string = require("string")
local table = require("table")
local _M = {}

local Picker = { 
	Layout = {},
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
				GroupOffset = 0,
				Start = 500,
				PlaceHolder = 15,
				Overwrite = true
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

function Picker.ApplyDefaults(target, defaults)
	-- if defaults not provided, assume target is self 
	defaults = defaults or target.Defaults or error("Boo.")
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            -- Recursively apply defaults to nested tables
            Picker.ApplyDefaults(target[key], value)
        else
            -- If the value is not present, apply the default value
            if target[key] == nil then
                target[key] = value
            end
        end
    end
end

function Picker:New(o)
	if not o or not o.Ranges or not o.Executors then
		return nil, "Invalid properties provided"
	end 	
    local obj = setmetatable(o, self)
    obj.__index = self     

	o:ApplyDefaults()
	o:Init()

	return obj
end

function Picker:Init()
	self.Groups = Obj.List(self.Ranges.Groups) -- FIXME Method=Copy: No groups
	self.Objects = Obj.List(self.Ranges.Objects)	

	local PickerWidth = math.min(15, math.ceil(#self.Objects / 5) * 5)

	if #self.Objects > 15 then return nil, "Max Picker Width exceeded" end
											 
	local RowPadding = PickerWidth - #self.Objects
	
	local macro_start
	local image_start
	local used_macros
	local used_images
	
	if self.Layout and self.Layout.Id then			
		used_macros = 16 * #self.Groups
		macro_start = self.Layout.Macros.Overwrite and self.Layout.Macros.Start or Obj.FindFreeRange('Macro', self.Layout.Macros.Start, used_macros)
		self.Layout.Macros.Start = macro_start
		self._Layout = Layout:New()
		if self.Layout.Images then
			used_images = 16 * #self.Groups
			image_start = self.Layout.Images.Overwrite and self.Layout.Images.Start or Obj.FindFreeRange('Image', self.Layout.Images.Start, used_images)
		end 
		self.Layout.Images.Start = image_start 
	end 
end

function Picker.prepareLayoutImages(guiImage, activeImage, inactiveImage, placeholder)
    if (Obj.IsEmpty('Image', activeImage)) then Cmd("Copy Image %d At %d", placeholder, activeImage) end
    if (Obj.IsEmpty('Image', inactiveImage)) then Cmd("Copy Image %d At %d", placeholder, inactiveImage) end
	if (Obj.IsEmpty('Image', guiImage)) then Cmd("Copy Image %d At %d", inactiveImage, guiImage) end
end

function Picker:CreateLayoutItem(Row, col, Exec, PickerWidth)
	local write_offset = (Row - 1) * 16 + col
	local source_offset = (Row - 1) * (self.Layout.Images.GroupOffset or 0) + (col - 1)
	
	local macro = self.Layout.Macros.Start + write_offset
	local active = self.Layout.Images.Active + source_offset
	local inactive = self.Layout.Images.Inactive + source_offset
	local picker = self.Layout.Images.Start + write_offset
	local placeholder = self.Layout.Images.Placeholder
	
	local image, geometry = {}, {}
	
	local inactiveList = string.format("%d Thru %d", self.Layout.Images.Inactive, self.Layout.Images.Inactive + PickerWidth - 1)
	local firstOfRow = self.Layout.Images.Picker + (Row - 1) * 16 + 1

	Picker.prepareLayoutImages(picker, active, inactive, placeholder)

	local macro_cmd = string.format(
		"Go Executor %d.%d ; Copy Image %s At %d /o; Copy Image %d At %d /o", 
		self.Executors.Page, 
		Exec, 
		inactiveList, 
		firstOfRow, 
		active, 
		picker)
	
	Cmd('Store Macro %d', macro_id)
	Cmd('Label Macro %d "%s"', macro_id, string.format("%s%sR%dC%d", self.VarsPrefix or '', self.VarsPrefix and '-' or '', Row, col))
	Cmd('Store Macro 1.%d.1 "%s"', macro_id, macro_cmd)
	
	local XOffset = self.Layout.XOffset or 0
	local YOffset = self.Layout.YOffset or 0					
	
	image.id = pickerImage
	image.label = Obj:New("Image "..active_image):Label()
	
	for _, rot in pairs({'90', '180', '270'}) do
		if (image.label):sub(-#rot) == rot then
			image.rotate = rot
		end
	end
	
	Picker.ApplyDefaults(geometry, Picker.Defaults.Layout.ButtonGeometry)
		
	geometry.x = (col - 1) * (geometry.Width + geometry.XSpacing) + XOffset 
	geometry.y = (Row - 1) * (geometry.Height + geometry.YSpacing) + YOffset
	
	self._Layout:addMacro(macro_id, geometry, image)
end

function Picker:Generate()

	local Exec = self.Executors.Start or Picker.Defaults.Executors.Start	

	local Row = 1
	for _, group in pairs(self.Groups) do	
		local g = sf.Obj:New(group)		
		local group_fixtures_count = #g:getFixtures()
		
		local col = 1		
		for _, obj in pairs(self.Objects) do			
			
			local obj = Obj:New(obj)
			-- Translate Object id - useful for different gobo sets across groups
			obj.Id = obj.Id + (self.Ranges.GroupOffset * (Row - 1))		
			local macro = ''									
			Cmd("ClearAll; Selfix %s; If %s", obj, group)			
			local fixtures_count = #Obj.GetFixtures() -- Count from programmer's selection
			Cmd("Clear")
			
			if (group_fixtures_count > 0) and (fixtures_count > 0) then			
				local cmd = self.VarsPrefix and string.format("SetVar $_%s_G%d %d", self.VarsPrefix, Row, Exec)				
				local opts = {
					label = obj:Label(),
					page = self.Executor.Page,
					exec = Exec,
					func = "Go",
					cmd = cmd,
					colorize = self.Executors.Colorize
				}
							
				Executor.FromObject(group, obj, opts):Label(g:Label())

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
-- Can create Macro matrix in a layout (with active/inactive image sources)
--[[
local myPicker = {
	Method = "Store",						-- "Store", "Copy", "Store+Copy"
	Label = "My Picker",					-- Label used both for Page name and Layout header (if applicable)
	VarsPrefix = "MP",						-- Variable name seed for Picker-Recall Macros ( $_{VarsPrefix}_G{Row} = Page.Exec )	
	Ranges = {
		Groups = "Group 1 Thru 5",			--
		Objects = "Preset 4.1 Thru 4.10"	--
		GroupOffset = 0						--	Offset added to Objects range after processing each group
	},	
	Executors = {					
		Page = 101,							--	Picker Page
		Start = 101,						-- 	First Executor 
		Colorize = "Object"					--	Copy color from: Preset, Effect, Group, { R, G, B }
	},	
	Layout = {
		Id = 150,							--	Layout id for this picker
		Header = "Line",					--	Picker header: nil, "Line", "Rectangle"		
		ButtonGeometry = {			
			Height = 1,				
			Width = 1,
			XSpacing = 0.1,
			YSpacing = 0.1
		},		
		Macros = {
			Start = 1000,
			Overwrite = true				--	If false, SF will seek a continuous range of empty macros starting from Macros.Start
		},		
		Images = {
			Active = 1,						--	First active image used for Buttons
			Inactive = 17,					-- 	First inactive image used for Buttons 
			Picker = 1000,					--  First picker image used for Buttons
			Generate = nil,					--	Delegate function used to generate Picker images (Not implemented yet)
			GroupOffset = 32				--	Offset images per group (Useful for gobo pickers)
		},		
		XOffset = 0,						-- Global layout X translation
		YOffset = 0,						-- Global layout Y translation 
		RegionHeight = nil,					-- Whole picker width (calculated)
		RegionWidth = nil					-- Whole picker height (calculated)
	}
}
]]--
