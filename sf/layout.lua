-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Layout module 

local base = _G
local Layout = { rectangles = {}, objects = {}, geometry = {}}; 
local _M = Layout 

function Layout:New(args)

	local o = Obj:New()
	setmetatable(o, Layout)
	
	if args and type(args) == 'string' then
		o._Name = args
		return o:Parse()
	elseif args and type(args) == 'table' then
		for k, v in pairs (args) do
			o[k] = v 
		end 
		return o:Parse()
	elseif args and type(args) == 'number' then
		o._Name = "Layout " .. args
		return o:Parse()
	elseif args ~= nil then 
		error("Layout:New() : Invalid args")
	end
	
	return o
end 

function Layout:PercentToAbsolute(geometry)

	if geometry.left and type(geometry.left) == 'string' and string.sub(geometry.left, -1) == '%' then		
		geometry.left = self.geometry.width * tonumber(string.sub(geometry.left, 1, string.len(geometry.left) -1)) / 100
		geometry.left = math.floor(geometry.left / 0.05 + 0.5) * 0.05 
	end 
	if geometry.width and type(geometry.width) == 'string' and string.sub(geometry.width, -1) == '%' then		
		geometry.width = self.geometry.width * tonumber(string.sub(geometry.width, 1, string.len(geometry.width) -1)) / 100
		geometry.width = math.floor(geometry.width / 0.05 + 0.5) * 0.05 
	end 
	if geometry.top and type(geometry.top) == 'string' and string.sub(geometry.top, -1) == '%' then		
		geometry.top = self.geometry.height * tonumber(string.sub(geometry.top, 1, string.len(geometry.top) -1)) / 100
		geometry.top = math.floor(geometry.top / 0.05 + 0.5) * 0.05 
	end 
	if geometry.height and type(geometry.height) == 'string' and string.sub(geometry.height, -1) == '%' then		
		geometry.height = self.geometry.height * tonumber(string.sub(geometry.height, 1, string.len(geometry.height) -1)) / 100
		geometry.height = math.floor(geometry.height / 0.05 + 0.5) * 0.05 
	end 
end 

function Layout:UpdateBounds(geometry)
	
	-- Update each bound if needed

	self.geometry.left   = math.min(tonumber(self.geometry.left),  geometry.x)
	self.geometry.right  = math.max(tonumber(self.geometry.right), geometry.x + geometry.width)
	self.geometry.top    = math.min(tonumber(self.geometry.top),   geometry.y)
	self.geometry.bottom = math.max(tonumber(self.geometry.bottom),   geometry.y + geometry.height)

	-- Calculate new footprint

	self.geometry.width = self.geometry.right - self.geometry.left
	self.geometry.height = self.geometry.bottom - self.geometry.top

end 

function Layout:addRectangle(geometry, text)

	self:PercentToAbsolute(geometry)
	self.rectangles[#self.rectangles+1] = string.format(self.xmlTemplate.rectangle, geometry.x, geometry.y, 
														geometry.height, geometry.width, text or "")
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
    self.objects[#self.objects+1] = string.format(self.xmlTemplate.macro, geometry.x or 0, geometry.y or 0, 
												  geometry.height or 1, geometry.width or 1, style, extra, image_chunk, id)
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