-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Object module 

local base = _G

local Obj = {
	ObjectType = '',		-- "Fixture", "Preset", "Image"
	Prefix = nil,			-- ExecutorPage, PresetType
	Id = nil
}

local _M = Obj

function Obj:Handle() 
	return Object.handle(self.Name())
end

function Obj:New(args)
    local o = setmetatable(type(args) == table and args or {}, self)
	if args then
		if type(args) == "string" then
			o._Name = args 
		elseif type(args) == "table" then 
			for k, v in pairs(args) do
				o[k] = v 
			end 
		end 		
	end	
	return o:Parse()
end

function Obj:Name()
	return string.format("%s %s%s%d", Obj._Normalize(self.ObjectType), self.Prefix or '', self.Prefix and '.' or '', self.Id)
end

function Obj:__tostring()
	return self:Name()
end

function Obj:__tonumber()
	return self:Handle()
end 

function Obj._Normalize(str)
	return string.upper(string.sub(str, 1, 1)) .. string.lower(string.sub(str, 2))
end

function Obj:Parse()
	if self._Name then self.ObjectType, self.Prefix, self.Id = string.match(self._Name, "^(%S*)%s*(%d*)%.?(%d+)$") end
	return self 
end 

function Obj:Label(label)
	label and Cmd('Label %s "%s"', self:Name(), label)
	return Object.label(self:Handle())
end

function Obj.SplitChunk(chunk)
    -- Pattern to match the structure "Class a.b THRU c.d"
    -- The components Class, a, and c are optional
    local class, a, b, c, d = chunk:upper():match("^(%S*)%s*(%d*)%.?(%d+)%s+THRU%s*(%d*)%.?(%S+)$")
    -- If any component is absent, assign nil
    return class ~= "" and class or nil, a ~= "" and a or nil, b, c ~= "" and c or nil, d
end

--	Checks if a Pool item slot is Empty
--	@param (string) objectType (Effect, Image, Sequence, Preset...)
-- 	@param (string) id (1, "MyGroup", 4.2...)
--	@return true if slot is empty, false otherwise
function Obj.isEmpty(objectType, id)
	return id and (Object.handle(string.format("%s %s", objectType, id)) == nil) or objectType:Handle() == nil
end

--	Checks if (length) (objectType(s)) are empty starting from id (firstId)
-- @param objectType Type of the Object (Effect, Image, Sequence, Preset...)
-- @param firstId First Pool item Id to check from
-- @param length Amount of successive empty pool items to Check
-- @return (Range Is Empty, Id to search from on next iteration)
function Obj.CheckRange(objectType, firstId, length)
	local rangeIsEmpty = true
	local nextFreeSlot = firstId
	for id = firstId, firstId + length do
		if not Obj.isEmpty(objectType, id) then
			rangeIsEmpty = false
			nextFreeSlot = id + 1
			break
		end
	end
	return rangeIsEmpty, nextFreeSlot
end

-- 	Returns the first id of (length) free objects in a row
--	@param (string) objectType "Image, Sequence, Macro..."
--	@param (int) firstId first id used to search
-- 	@param (int) length amount of free objects to find
--  @param harmonize [default=nil] Can be nil, false, true, or a number
--         Force first Id of the returned range to be a multiple of N
--		   harmonize==nil,false => N=1, harmonize==true => N=16, harmonize==M => N=M
function Obj.FindFreeRange(objectType, firstId, length, harmonize)
	local nextFreeSlot = firstId
	local empty = false
	harmonize = harmonize and ((type(harmonize) == "number") and harmonize or 16) or false
	Debug("> Pool item grid snap: %d", harmonize or 0)
	Debug("> empty set to false")
	while (not empty) do
	    Debug("    - pre-snap seek id: %d", nextFreeSlot)
		if harmonize then nextFreeSlot = math.ceil(nextFreeSlot / harmonize) * harmonize end
		Debug("    - post-snap seek id: %d", nextFreeSlot)		
		empty, nextFreeSlot = Obj.CheckRange(objectType, nextFreeSlot, length)
		Debug("    empty: %d, seek from: %d", empty and 1 or 0, nextFreeSlot or -1)		
	end
	return nextFreeSlot
end

-- Build a table of all Objects listed in @param expression
-- @param expression List of Objects (e.g., "Fixture 1 Thru 5", "Preset 4.15 Thru 30", Fixture 1)
-- @return A table containing all Objects from the given expression
-- @example @param expression "Preset 2.1 Thru 2.3" => {"Preset 2.1", "Preset 2.2", "Preset 2.3"}
function Obj.List(expression, objectType)
    local chunks = {}
    local objects = {}
    for element in string.gmatch(expression, "([^+]+)") do
        chunks[#chunks+1] = element
    end
    for _, chunk in pairs(chunks) do
        if string.match(string.upper(chunk), 'THRU') then
			chunk = chunk:gsub("^%s*(.-)%s*$", "%1")
            local _objectType, fromPrefix, fromId, toPrefix, toId = Obj.SplitChunk(chunk)
			objectType = _objectType or objectType 
            for id = tonumber(fromId), tonumber(toId), ((toId > fromId) and 1 or -1) do
                objects[#objects+1] = Obj.New{ObjectType=objectType, Id=id, Prefix=fromPrefix}:Name()
            end
        else
			local o = Obj.New(chunk)
			if objectType then o.ObjectType = objectType end			
            objects[#objects+1] = o:Name()
			Debug(chunk)
        end
    end
    return objects
end

-- source:
--   number: Group Id
--   string: Object
--   table with .Name: assume source is self -- instance:GetFixtures()
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
	elseif source and type(source) == table and source.Name 
		Cmd("Selfix %s", source:Name())
	else -- Selection in programmer
		-- do nothing
	end
	
	local test_group = Obj.FindFreeRange("Group", 500, 1)

	Cmd('Store Group %d', test_group)
	Cmd('SelectDrive 1')	
	Cmd('Export Group %d "%s"', test_group, file.name)
	Cmd('Clear')
	
	source or Cmd('Group %d', test_group) -- Restore selection in programmer
	
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