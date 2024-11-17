-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Layout module 

local Obj = require("showfunctions.obj")
local Layout = { 
	Rectangles = {}, 
	Objects = {}, 
	Geometry = {
		Left=0, Right=0, Top=0, Bottom=0, Width=0, Height=0
	}
}

setmetatable(Layout, {__index = Obj})

local _M = Layout 

--- Creates a new Layout object.
-- @param args The argument can be:
--   - A string: Sets the `_Name` property to the string value.
--   - A table: Copies the table's key-value pairs into the object.
--   - A number: Sets the `_Name` property to a string prefixed with "Layout ".
-- @return The new Layout object.
-- @error If `args` is invalid or of an unsupported type, it raises an error.
function Layout:New(args)
    local obj = Obj:New(args)     -- Create an instance from the base class Obj
    setmetatable(obj, self)       -- Set metatable to Layout to link to its methods
	self.__index = self

    -- Initialize the object based on the provided argument type
    if args then
        if type(args) == 'string' then
            obj._Name = args
        elseif type(args) == 'number' then
            obj._Name = "Layout " .. args
        else
            error("Layout:New() : Unsupported argument type. Expected string, table, or number.")
        end
    end
    -- If parsing is required (e.g., initialization logic), call Parse

	Obj.Parse(obj)
    return obj
end

--- Converts percentage-based coordinates to absolute values relative to the total width/height.
-- @param geometry (table) The geometry table containing coordinates (left, right, top, bottom).
-- @param gridsize (number) The grid size to round the values to.
-- @return None. The geometry table is updated with the absolute values.
function Layout:PercentToAbsolute(geometry, gridsize)
	local gridsize = gridsize or 0.05
    for _, v in ipairs{
        {geometry.Left, self.Geometry.Width},
        {geometry.Right, self.Geometry.Width},
        {geometry.Top, self.Geometry.Height},
        {geometry.Bottom, self.Geometry.Height}
    } do local coord, length = v[1], v[2]
        if coord and type(coord) == 'string' and string.sub(coord, -1) == '%' then
            coord = length * tonumber(string.sub(coord, 1, #coord - 1)) / 100
            coord = math.floor(coord / gridsize + 0.5) * gridsize
        end
    end
end

function Layout:UpdateBounds(geometry)
	Debug("Layout:UpdateBounds() ======================================")
	DebugTable("Layout Geometry", self.Geometry)
	DebugTable("Object Geometry", geometry)
	Debug("Entering function     ======================================")
	
	-- Update each bound if needed

	self.Geometry.Left   = math.min(tonumber(self.Geometry.Left),  geometry.X)
	self.Geometry.Right  = math.max(tonumber(self.Geometry.Right), geometry.X + geometry.Width)
	self.Geometry.Top    = math.min(tonumber(self.Geometry.Top),   geometry.Y)
	self.Geometry.Bottom = math.max(tonumber(self.Geometry.Bottom),   geometry.Y + geometry.Height)

	-- Calculate new footprint

	self.Geometry.Width = self.Geometry.Right - self.Geometry.Left
	self.Geometry.Height = self.Geometry.Bottom - self.Geometry.Top
	DebugTable("New Layout Geometry", self.Geometry)
end 

function Layout:addRectangle(geometry, text)

	self:PercentToAbsolute(geometry)
	self.Rectangles[#self.Rectangles+1] = string.format(self.xmlTemplate.rectangle, geometry.X, geometry.Y, 
														geometry.Height, geometry.Width, text or "")
	self:UpdateBounds(geometry)	
	return self
end 

function Layout:addMacro(id, geometry, image)

	self:PercentToAbsolute(geometry)
	local image_chunk = '<image />'
	local extra = ''
	local style = image and "Simple" or "Pool Item"
    if image then	
		extra = ' image_size="Fit"'
		image_chunk = string.format('<image name="Image"><No>8</No><No>%d</No></image>', image.id)
		
		if image.rotation and (image.rotation == 90 or image.rotation == 180 or image.rotation == 270) then
			extra = extra .. string.format(' image_rotation="%d°"', image.rotation)
		end		
	end    
    self.Objects[#self.Objects+1] = string.format(self.xmlTemplate.macro, geometry.X or 0, geometry.Y or 0, 
												  geometry.Height or 1, geometry.Width or 1, style, extra, image_chunk, id)
	self:UpdateBounds(geometry)
	return self
end

function Layout:Store(id)

	id = id or self.Id
	local file = {}	
	file.name = "_import_layout.xml"
	file.path = Show.getvar('PATH') .. "/importexport/"
	file.xml = file.path .. file.name
	
	file.data = io.open(file.xml, "w")	
    file.data:write(self.xmlTemplate.header)    
    file.data:write(table.concat(self.Objects))    
    file.data:write('</CObjects>')	
	
	if #self.Rectangles > 0 then	
		file.data:write('<Rectangles>')
		file.data:write(table.concat(self.Rectangles))
		file.data:write('</Rectangles>')	
	end	
	
	file.data:write(self.xmlTemplate.footer)   
    file.data:close()    
    Cmd('Import "%s" at layout %d /nc', file.name, id)    
    os.remove(file.xml)	
	
	
	return self
end

Layout.xmlTemplate = {
	rectangle	= '<LayoutElement font_size="Small" center_x="%f" center_y="%f" size_h="%f" size_w="%f" background_color="00000000" icon="None" text="%s" show_id="1" show_name="1" show_type="1" show_dimmer_bar="Off" show_dimmer_value="Off"><image /></LayoutElement>',
	macro 		= '<LayoutCObject font_size="Small" center_x="%f" center_y="%f" size_h="%f" size_w="%f" background_color="3c3c3c" border_color="5a5a5a" icon="None" show_id="0" show_name="0" show_type="0" function_type="%s" select_group="1"%s>%s<CObject name="Foo"><No>13</No><No>1</No><No>%d</No></CObject></LayoutCObject>',
	header 		= '<?xml version="1.0" encoding="utf-8"?><MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.9.60/MA.xsd" major_vers="3" minor_vers="9" stream_vers="60"><Info datetime="2024-05-12T15:57:58" showfile="" /><Group index="0" name="Empty"><LayoutData index="0" marker_visible="true" snap_always_active="true" background_color="000000" visible_grid_h="1" visible_grid_w="0" snap_grid_h="0.1" snap_grid_w="0.1" default_gauge="Filled &amp; Symbol" subfixture_view_mode="DMX Layer"><CObjects>',
	footer		= '</LayoutData></Group></MA>'
}

return _M