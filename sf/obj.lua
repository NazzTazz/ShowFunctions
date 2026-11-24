-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Optimized Object module with LDoc documentation
local base = _G
local Tools = require("showfunctions.tools")

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

--- Splits an object reference into type, prefix and id.
-- "Preset 4.12" -> "Preset", 4, 12 ; "Group 3" -> "Group", nil, 3 ; "311" -> nil, nil, 311
-- The type is made of letters only, and a prefix exists only when there is a dot:
-- a bare number is never split into type/prefix/id.
-- @param str The reference to split.
-- @return string|nil, number|nil, number|nil Type, prefix and id (all nil if str is not a reference).
function Obj.SplitName(str)
    str = (str or ''):match("^%s*(.-)%s*$")
    local objectType, rest = str:match("^(%a*)%s*(.-)$")
    local prefix, id = rest:match("^(%d+)%.(%d+)$")
    if not id then
        id = rest:match("^(%d+)$")
    end
    if not id then
        return nil, nil, nil
    end
    return (#objectType > 0) and objectType or nil, tonumber(prefix), tonumber(id)
end

--- Parses the object name to extract components.
-- Sets ObjectType, Prefix, and Id from the object name.
-- @return table The object itself with updated attributes.
function Obj.Parse(self)
    if self._Name then
        self.ObjectType, self.Prefix, self.Id = Obj.SplitName(self._Name)
        Debug("Obj.Parse() %s -> Ot: %s Prefix: %s Id: %s",
            tostring(self._Name), tostring(self.ObjectType), tostring(self.Prefix), tostring(self.Id))
    end
    return self
end

--- Creates a new object.
-- @param args Can be a string (object name) or a table of object attributes.
-- @return table A new object with parsed attributes.
function Obj:New(args)
    local obj = type(args) == 'table' and args or {}
	setmetatable(obj, self)
	obj.__index = self

    if type(args) == "string" then
        obj._Name = args
    end
    Obj.Parse(obj)

	return obj
end

--- Generates the full name of the object.
-- @return string The formatted object name.
function Obj:Name()
	
	assert(self.ObjectType and self.Id, "Obj:Name(): object without type or id")
	self._Name = string.format("%s %s%d", Obj._Normalize(self.ObjectType), self.Prefix and self.Prefix .. '.' or '', self.Id)
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


--- Sets or gets the label of the object.
-- @param label (optional) The label to set for the object.
-- @return string The current label of the object.
function Obj:Label(label)
    if label then
        Cmd('Label %s "%s"', self:Name(), label)
    end
    local handle = self:Handle()
    return handle and Object.label(handle) -- nil if the object doesn't exist (or has no label)
end

--- Splits a "A Thru B" chunk.
-- The right bound inherits type and prefix from the left one: "Preset 4.1 Thru 10" -> Preset 4.1 .. Preset 4.10
-- @param chunk A string chunk to split.
-- @return string|nil, number|nil, number, number|nil, number Type, fromPrefix, fromId, toPrefix, toId (nil if invalid).
function Obj.SplitChunk(chunk)
    local left, right = chunk:upper():match("^(.-)%s*THRU%s*(.-)$")
    if not left then return nil end
    local objectType, fromPrefix, fromId = Obj.SplitName(left)
    local toType, toPrefix, toId = Obj.SplitName(right)
    if not (fromId and toId) then return nil end
    return objectType or toType, fromPrefix, fromId, toPrefix or fromPrefix, toId
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
-- Each element inherits type and prefix from the previous one when it has none:
-- "Fixture 123 Thru 127 + 2477 Thru 2483 + 311" -> Fixture 123 .. Fixture 127, Fixture 2477 .. Fixture 2483, Fixture 311
-- @param expression A string expression (e.g., "Preset 2.1 Thru 2.3").
-- @param objectType (optional) The default object type if not specified in the expression.
-- @return table A list of object names matching the expression.
function Obj.List(expression, objectType)
    local objects = {}
    local prefix = nil

    local function name(t, p, id)
        assert(t, string.format("Obj.List(): no object type for '%s'", expression))
        return string.format("%s %s%d", Obj._Normalize(t), p and p .. '.' or '', id)
    end

    for element in expression:gmatch("([^+]+)") do
        element = element:match("^%s*(.-)%s*$") -- trim whitespace
        if element:upper():find('THRU') then
            local t, fromPrefix, fromId, toPrefix, toId = Obj.SplitChunk(element)
            assert(fromId, string.format("Obj.List(): can't read '%s'", element))
            objectType = t or objectType
            fromPrefix = fromPrefix or prefix
            if toPrefix and fromPrefix and toPrefix ~= fromPrefix then
                error(string.format("Obj.List(): '%s' spans two pools, not supported", element))
            end
            for id = fromId, toId, (toId >= fromId) and 1 or -1 do
                objects[#objects + 1] = name(objectType, fromPrefix, id)
            end
            prefix = fromPrefix
        elseif #element > 0 then
            local t, p, id = Obj.SplitName(element)
            assert(id, string.format("Obj.List(): can't read '%s'", element))
            objectType = t or objectType
            prefix = p or (t == nil and prefix) or nil
            objects[#objects + 1] = name(objectType, prefix, id)
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

    file.name = '_tmp_fxtlst.xml'
    file.path = gma.show.getvar('PATH') .. '/' .. 'importexport' .. '/' .. file.name

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

    if not source then
        Cmd('Group %d', test_group)
    end -- Restore selection in programmer

    Cmd('Delete Group %d /nc', test_group)

    for line in io.lines(file.path) do
        if (string.find(line, 'Subfixture fix_id') or string.find(line, 'Subfixture cha_id')) then
            objectType = string.find(line, 'fix_id') and 'Fixture' or 'Channel'
            local indices = {string.find(line, '\"%d+\"')}
            indices[1], indices[2] = indices[1] + 1, indices[2] - 1
            fixtures[#fixtures + 1] = string.format("%s %s", objectType, string.sub(line, indices[1], indices[2]))
        end
    end

    os.remove(file.path)
    return fixtures
end

return _M
