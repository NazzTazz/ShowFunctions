-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Executor module 

local base = _G

local Executor = { 
	Page = 0
}

local _M = Executor 

--	Creates an Executor from given group/object
--	@param (string) group: Group on which will be applied the object
--	@param (string) obj: Object to apply on the group (e.g: Effect 1, Preset 0.1 ...)
--  @param (table) opts: Values and options
--	 (string) 		.exec: Executor to write to (e.g: 5, 100.101 ...)
--   (int)    		.cue: Cue used when storing (optionnal: default=1)
--	 (string) 		.label: Label of the executor (or cue) (optionnal)
--	 (string) 		.cmd: Command to inject to the Cue (optionnal)
--	 (string) 		.func: Function to assign on the executor (e.g: Go, Goto, Flash, Temp ...) (optionnal)
--	 (float)  		.fade: Fade time applied to the cue (optionnal)
--	 (float)  		.offtime: Executor offtime (optionnal)

-- function Executor:FromObject(group, obj, label, exec, cue, cmd, func, fade, offtime)
-- label, exec, cue, cmd, func, fade, offtime
function Executor:FromObject(group, obj, opts)
	c = opts.colorize
	if c then
		if type(c) == 'table' and #c == 3 then
			opts.appearance = string.format("/r=%d /g=%d /b=%d", c[1], c[2], c[3])
		elseif type(c) == 'string' and c == 'Group' then
			opts.appearance = string.format("At %s", group)
		elseif type(c) == 'string' and c == 'Object' then 
			opts.appearance = string.format("At %s", obj)
		end 
	end
	opts.exec = opts.cue and string.format("Cue %d Executor %s", opts.cue, opts.exec) or string.format("Executor %s", opts.exec)
	Cmd("Group %s; At %s; Store %s /o; ClearAll", group, obj, opts.exec)
	opts.label and Cmd('Label %s "%s"', opts.exec, opts.label)
	opts.cmd and Cmd('Assign %s /cmd="%s"', opts.exec, opts.cmd)
	opts.func and Cmd ("Assign %s %s", opts.func, opts.exec)
	opts.fade and Cmd ("Assign Fade %d %s", opts.fade, opts.exec)
	opts.offtime and Cmd ("Assign %s /offtime=%d", opts.exec, opts.offtime)
	opts.appearance and Cmd("Appearance %s %s", opts.exec, opts.appearance)
end

return _M