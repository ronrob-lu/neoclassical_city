-- neoclassical_city: Standalone Luanti/Minetest mod adapted from Amenaza's
-- neoclassical city mapgen, allowing players to build the city manually anywhere
-- via chat commands, with steady and blinking lanterns and windows.

neoclassical_city = {}

local modpath = minetest.get_modpath(minetest.get_current_modname())

dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/blinking.lua")
dofile(modpath .. "/citygen.lua")
