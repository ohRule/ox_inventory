--[[
  Furnace: ore goes in the ore tray, wood/fuel in the fuel tray, toggle ON.
  Each cycle consumes the recipe item plus fuel, then drops bars in the output.
]]

return {
	-- Any of these in the input grid counts as fuel (consumed per cycle).
	fuel = {
		wood = true,
		cutted_wood = true,
		packaged_plank = true,
	},

	recipes = {
		-- 5 scrap + 1 wood -> 1 iron
		scrapmetal = { duration = 6000, consume = 5, fuel = 1, output = { iron = 1 } },
		-- Washed stone + wood -> copper
		washed_stone = { duration = 8000, consume = 1, fuel = 1, output = { copper = 1 } },
		-- Extra copper from raw copper if you treat it as ore
		-- copper = { duration = 7000, consume = 2, fuel = 1, output = { gold = 1 } },
	},

	locations = {
		{
			id = 'garage_furnace',
			label = 'Furnace',
			-- Next to the garage workbench
			coords = vec4(713.70, -1088.91, 22.36, 90.0),
			prop = `prop_hobo_stove_01`,
			distance = 3.0,
			blip = { id = 436, colour = 1, scale = 0.7 },
		},
	},
}
