-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Executor module 

local Obj = require("showfunctions.obj")
local Tools = require("showfunctions.tools")

local Executor = { 
	Page = 0
}

local _M = Executor 

--	Creates an Executor from given group/object
--	@param (string) group: Group on which will be applied the object
--	@param (string) obj: Object to apply on the group (e.g: Effect 1, Preset 0.1 ...)
--  @param (table) opts: Values and options
--   (int)			.page: Executor page 
--	 (int) 			.exec: Executor to write to (e.g: 5, 101 ...)
--   (int)    		.cue: Cue used when storing (optionnal: default=1)
--	 (string) 		.label: Label of the executor (or cue) (optionnal)
--	 (string) 		.cmd: Command to inject to the Cue (optionnal)
--	 (string) 		.func: Function to assign on the executor (e.g: Go, Goto, Flash, Temp ...) (optionnal)
--	 (float)  		.fade: Fade time applied to the cue (optionnal)
--	 (float)  		.offtime: Executor offtime (optionnal)

-- function Executor:FromObject(group, obj, label, exec, cue, cmd, func, fade, offtime)
-- label, exec, cue, cmd, func, fade, offtime
function Executor.FromObject(group, obj, opts)
	local c = opts.colorize
	if c then
		if type(c) == 'table' and #c == 3 then
			opts.appearance = string.format("/r=%d /g=%d /b=%d", c[1], c[2], c[3])
		elseif type(c) == 'string' and c == 'Group' then
			opts.appearance = string.format("At %s", group)
		elseif type(c) == 'string' and c == 'Object' then 
			opts.appearance = string.format("At %s", obj)
		end 
	end
	
	local exec = string.format("Executor %d.%d", opts.page, opts.exec)
	local cue  = opts.cue and string.format("Cue %d Executor %d.%d", opts.cue, opts.page, opts.exec) or exec

	Cmd("%s; At %s; Store %s /o; ClearAll", group, obj, cue)
	if opts.label then Cmd('Label %s "%s"', cue, opts.label) end
	if opts.cmd then Cmd('Assign %s /cmd="%s"', cue, opts.cmd) end 
	if opts.func then Cmd ("Assign %s %s", opts.func, exec) end 
	if opts.fade then Cmd ("Assign Fade %d %s", opts.fade, cue) end 
	if opts.offtime then Cmd ("Assign %s /offtime=%d", exec, opts.offtime) end 
	if opts.appearance then Cmd("Appearance %s %s", exec, opts.appearance) end 
	return Obj:New(exec)
end

return _M