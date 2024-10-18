ShowFunctions is a LUA library for MA Lighting GrandMa 2 Series of lighting desks (Including OnPC)
It allows LUA enthousiasts to easily write plugins for their own showfiles.

Need a fancy color picker, with customizable images, for groups 1 thru 6 ?

Import ShowFunctions.xml to your showfile and try this:

local colorPicker = 
{	FirstGroup = 1,
	LastGroup = 6,
	FirstId = 1,
	LastId = 15,
	Page = 42,
	UseLayout = true,
	FirstInactiveImage = 1,
	FirstActiveImage = 17,
	FirstMacro = 100,
	Layout = 1 }
 
createPicker('Preset', 4, colorPicker, 'Preset')	


	
