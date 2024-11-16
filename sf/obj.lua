-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Optimized Object module with LDoc documentation

local base = _G

local Obj = {
	ObjectType = '',
	Prefix = nil,
	Id = nil,
	_Name = nil
}

local _M = Obj
Obj.__index = Obj

--- Gets the object handle.
-- @return handle The handle of the object based on its name.
function Obj:Handle()
	return Object.handle(self._Name or self:Name())
end

--- Creates a new object.
-- @param args Can be a string (object name) or a table of object attributes.
-- @return table A new object with parsed attributes.
function Obj:New(args)
	local obj = setmetatable({}, self)
	if type(args) == "string" then
		obj._Name = args
	elseif type(args) == "table" then
		for k, v in pairs(args) do
			obj[k] = v
		end
	end
	return obj:Parse()
end

--- Generates the full name of the object.
-- @return string The formatted object name.
function Obj:Name()
	if not self._Name then
		self._Name = string.format("%s %s%s%d", Obj._Normalize(self.ObjectType), self.Prefix or '', self.Prefix and '.' or '', self.Id)
	end
	return self._Name
end

--- Converts the object to a string representation.
-- @return string The name of the object.
function Obj:__tostring()
	return self:Name()
end

--- Converts the object to a number (handle).
-- @return number The handle of the object.
function Obj:__tonumber()
	return self:Handle()
end

--- Normalizes the object type string.
-- @param str The string to normalize.
-- @return string The normalized string.
local normalization_cache = {}
function Obj._Normalize(str)
	if not normalization_cache[str] then
		normalization_cache[str] = string.upper(string.sub(str, 1, 1)) .. string.lower(string.sub(str, 2))
	end
	return normalization_cache[str]
end

--- Parses the object name to extract components.
-- Sets ObjectType, Prefix, and Id from the object name.
-- @return table The object itself with updated attributes.
function Obj:Parse()
	if self._Name then
		self.ObjectType, self.Prefix, self.Id = string.match(self._Name, "^(%S*)%s*(%d*)%.?(%d+)$")
		self.Id = tonumber(self.Id)
	end
	return self
end

--- Sets or gets the label of the object.
-- @param label (optional) The label to set for the object.
-- @return string The current label of the object.
function Obj:Label(label)
	if label then Cmd('Label %s "%s"', self:Name(), label) end
	return Object.label(self:Handle())
end

--- Splits an expression chunk into components.
-- @param chunk A string chunk to split.
-- @return string, string, string, string, string Components of the split chunk.
function Obj.SplitChunk(chunk)
	return chunk:upper():match("^(%S*)%s*(%d*)%.?(%d+)%s+THRU%s*(%d*)%.?(%S+)$")
end

--- Checks if a slot is empty.
-- @param objectType The type of the object (e.g., "Preset", "Fixture").
-- @param id The ID of the object.
-- @return boolean True if the slot is empty, false otherwise.
function Obj.isEmpty(objectType, id)
	return id and Object.handle(string.format("%s %s", objectType, id)) == nil
end

--- Checks if a range of slots are empty.
-- @param objectType The type of the object.
-- @param firstId The starting ID to check.
-- @param length The number of consecutive slots to check.
-- @return boolean, number Whether the range is empty, and the next free slot.
function Obj.CheckRange(objectType, firstId, length)
	for id = firstId, firstId + length - 1 do
		if not Obj.isEmpty(objectType, id) then
			return false, id + 1
		end
	end
	return true, firstId + length
end

--- Finds the first free range of slots.
-- @param objectType The type of the object.
-- @param firstId The starting ID for the search.
-- @param length The number of free slots to find.
-- @param harmonize Optional harmonization value (e.g., 16).
-- @return number The ID of the first free range.
function Obj.FindFreeRange(objectType, firstId, length, harmonize)
	harmonize = (type(harmonize) == "number" and harmonize > 0) and harmonize or (harmonize and 16 or 1)
	local nextFreeSlot = math.ceil(firstId / harmonize) * harmonize
	while true do
		local empty, nextSlot = Obj.CheckRange(objectType, nextFreeSlot, length)
		if empty then
			return nextFreeSlot
		end
		nextFreeSlot = math.ceil(nextSlot / harmonize) * harmonize
	end
end

--- Builds a list of objects based on the provided expression.
-- @param expression A string expression (e.g., "Preset 2.1 Thru 2.3").
-- @param objectType (optional) The default object type if not specified in the expression.
-- @return table A list of object names matching the expression.
function Obj.List(expression, objectType)
	local objects = {}
	for element in expression:gmatch("([^+]+)") do
		element = element:match("^%s*(.-)%s*$") -- trim whitespace
		if element:upper():find('THRU') then
			local _objectType, fromPrefix, fromId, toPrefix, toId = Obj.SplitChunk(element)
			objectType = _objectType or objectType
			local fromId, toId = tonumber(fromId), tonumber(toId)
			for id = fromId, toId do
				table.insert(objects, Obj.New{ObjectType=objectType, Id=id, Prefix=fromPrefix}:Name())
			end
		else
			local o = Obj.New(element)
			if objectType then o.ObjectType = objectType end
			table.insert(objects, o:Name())
		end
	end
	return objects
end

--- Gets Fixture List
-- @param source:
--   number: Group Id
--   string: Object
--   table with :Name(): assume source is self -- instance:GetFixtures()
--	 nil: From programmer 
function Obj.GetFixtures(source)
	local objectType
	local fixtures = {}
	local file = {}

	file.name =	'_tmp_fxtlst.xml'
	file.path =	gma.show.getvar('PATH')..'/'..'importexport'..'/' .. file.name

	if source and type(source) == "number" then -- Group Id 
		Cmd("Selfix Group %d", source)
	elseif source and type(source) == "string" then -- Object to Selfix
		Cmd("Selfix %s", source)
	elseif source and type(source) == "table" and source.Name and type(source.Name) == 'function' then
		Cmd("Selfix %s", source:Name())
	else -- Selection in programmer
		-- do nothing
	end
	
	local test_group = Obj.FindFreeRange("Group", 500, 1)

	Cmd('Store Group %d', test_group)
	Cmd('SelectDrive 1')	
	Cmd('Export Group %d "%s"', test_group, file.name)
	Cmd('Clear')
	
	if not source then Cmd('Group %d', test_group) end -- Restore selection in programmer
	
	Cmd('Delete Group %d /nc', test_group)

	for line in io.lines(file.path) do
		if (string.find(line, 'Subfixture fix_id') 
		or  string.find(line, 'Subfixture cha_id')) then
			objectType = string.find(line, 'fix_id') and 'Fixture ' or 'Channel '
			local indices = {string.find(line, '\"%d+\"')}
			indices[1], indices[2] = indices[1] + 1, indices [2] - 1
			fixtures[#fixtures+1] = string.format("%s %s", objectType, string.sub(line, indices[1], indices[2]))
		end
	end

	os.remove(file.path)
	return fixtures
end

return _M