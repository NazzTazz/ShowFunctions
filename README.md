# ShowFunctions
ShowFunctions is a LUA library for MA Lighting GrandMa 2 Series of lighting desks (Including OnPC)
It allows LUA enthousiasts to easily write plugins for their own showfiles.

## Need a fancy color picker, with customizable images, for groups 1 thru 6 ?

'''

local SF = require("showfunctions")

local Picker = {
	Executors = {
		Page = 1,
		Start = 101,
		Colorize = 'Object'
	},
	Ranges = {
		Groups = "Group 1 Thru 5",
		Objects = "Preset 4.1 Thru 10"
	}
}

SF.Picker:New(Picker):Generate()

'''

	
