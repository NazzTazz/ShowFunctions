-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Layout module 

local base = _G
local Layout = { rectangles = {}, objects = {}}; 
local _M = Layout 

local LayoutElement = {
	x = nil,
	y = nil,
	width = nil,
	height = nil
}

function LayoutElement:New()
	local o = setmetatable({}, { __index = self }
	return o
end 

function Layout:New()
    local o = setmetatable({}, { __index = self })
    return o
end

function Layout:addRectangle(geometry, text)
	self.rectangles[#self.rectangles+1] = string.format(self.xmlTemplate.rectangle, geometry.x, geometry.y, 
														geometry.height, geometry.width, text or "")
	return self
end 

function Layout:addMacro(id, geometry, image)
    local xml 
	local image_chunk = '<image />'
	local extra = ''
	local style = image and "Simple" or "Pool Item"
    if image then	
		extra = ' image_size="Fit"'
		if image.rotation and (image.rotation == 90 or image.rotation == 180 or image.rotation == 270) then
			extra = extra .. string.format(' image_rotation="%d°"', image.rotation)
		end		
		image_chunk = string.format('<image name="Image"><No>8</No><No>%d</No></image>', image.id)		
	end    
    self.objects[#self.objects+1] = string.format(self.xmlTemplate.macro, geometry.x or 0, geometry.y or 0, 
												  geometry.height or 1, geometry.width or 1, style, extra, image_chunk, id)
end

function Layout:Store(id)
	local file = {}	
	file.name = "_import_layout.xml"
	file.path = Show.getvar('PATH') .. "/importexport/"
	file.xml = file.path .. file.name
	file.data = io.open(file.xml, "w")	
    file.data:write(self.xmlTemplate.header)    
    file.data:write(table.concat(self.objects))    
    file.data:write('</CObjects>')	
	if #self.rectangles > 0 then	
		file.data:write('<Rectangles>')
		file.data:write(table.concat(self.rectangles))
		file.data:write('</Rectangles>')	
	end	
	file.data:write(self.xmlTemplate.footer)   
    file.data:close()    
    Cmd('Import "%s" at layout %d /nc', file.name, id)    
    os.remove(file.xml)	
	return self
end

_M.xmlTemplate = {
	rectangle	= '<LayoutElement font_size="Small" center_x="%f" center_y="%f" size_h="%f" size_w="%f" background_color="00000000" icon="None" text="%s" show_id="1" show_name="1" show_type="1" show_dimmer_bar="Off" show_dimmer_value="Off"><image /></LayoutElement>',
	macro 		= '<LayoutCObject font_size="Small" center_x="%f" center_y="%f" size_h="%f" size_w="%f" background_color="3c3c3c" border_color="5a5a5a" icon="None" show_id="0" show_name="0" show_type="0" function_type="%s" select_group="1"%s>%s<CObject name="Foo"><No>13</No><No>1</No><No>%d</No></CObject></LayoutCObject>',
	header 		= '<?xml version="1.0" encoding="utf-8"?><MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.9.60/MA.xsd" major_vers="3" minor_vers="9" stream_vers="60"><Info datetime="2024-05-12T15:57:58" showfile="" /><Group index="0" name="Empty"><LayoutData index="0" marker_visible="true" snap_always_active="true" background_color="000000" visible_grid_h="1" visible_grid_w="0" snap_grid_h="0.1" snap_grid_w="0.1" default_gauge="Filled &amp; Symbol" subfixture_view_mode="DMX Layer"><CObjects>',
	footer		= '</LayoutData></Group></MA>'
}

return _M