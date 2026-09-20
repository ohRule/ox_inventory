-- Tarkov-style world loot. Each location spawns a prop with a category pool.
-- chance is 1-100. min/max is how many of that item drop when it rolls.

return {
	-- Delay between each revealed item while searching
	searchDelay = 550,
	-- Seconds after generation before the crate restocks
	resetTime = 600,
	-- Hard cap for every prop
	slots = 5,
	maxItems = 5,

	categories = {
		ammo = {
			label = 'Ammo Crate',
			minItems = 1,
			emptyChance = 12,
			items = {
				{ name = 'ammo-9', min = 1, max = 2, chance = 45 },
				{ name = 'ammo-45', min = 1, max = 2, chance = 30 },
				{ name = 'ammo-rifle', min = 1, max = 1, chance = 22 },
				{ name = 'ammo-rifle2', min = 1, max = 1, chance = 14 },
				{ name = 'ammo-shotgun', min = 1, max = 2, chance = 28 },
				{ name = 'empty_9_magazine', min = 1, max = 1, chance = 20 },
				{ name = 'empty_rifle_magazine', min = 1, max = 1, chance = 14 },
				{ name = 'WEAPON_PISTOL', min = 1, max = 1, chance = 5 },
				{ name = 'WEAPON_BAT', min = 1, max = 1, chance = 8 },
				{ name = 'armour', min = 1, max = 1, chance = 6 },
			},
		},

		medical = {
			label = 'Medical Bag',
			minItems = 1,
			emptyChance = 10,
			items = {
				{ name = 'bandage', min = 1, max = 3, chance = 60 },
				{ name = 'medikit', min = 1, max = 1, chance = 28 },
				{ name = 'water', min = 1, max = 2, chance = 25 },
				{ name = 'burger', min = 1, max = 1, chance = 15 },
			},
		},

		tool = {
			label = 'Toolbox',
			minItems = 1,
			emptyChance = 15,
			items = {
				{ name = 'lockpick', min = 1, max = 2, chance = 35 },
				{ name = 'fixkit', min = 1, max = 1, chance = 25 },
				{ name = 'fixtool', min = 1, max = 1, chance = 20 },
				{ name = 'carotool', min = 1, max = 1, chance = 18 },
				{ name = 'blowpipe', min = 1, max = 1, chance = 12 },
				{ name = 'scrapmetal', min = 1, max = 4, chance = 32 },
			},
		},

		crate = {
			label = 'Crate',
			minItems = 0,
			emptyChance = 20,
			items = {
				{ name = 'garbage', min = 1, max = 2, chance = 40 },
				{ name = 'scrapmetal', min = 1, max = 3, chance = 35 },
				{ name = 'lockpick', min = 1, max = 1, chance = 16 },
				{ name = 'money', min = 15, max = 80, chance = 22 },
				{ name = 'water', min = 1, max = 1, chance = 20 },
				{ name = 'burger', min = 1, max = 1, chance = 18 },
				{ name = 'phone', min = 1, max = 1, chance = 8 },
				{ name = 'radio', min = 1, max = 1, chance = 5 },
			},
		},
	},

	locations = {
		-- Medical
		{ id = 'pillbox_med', category = 'medical', coords = vec4(311.42, -592.91, 43.28, 70.0), prop = `prop_stat_pack_01` },
		{ id = 'davis_med', category = 'medical', coords = vec4(298.48, -1444.12, 29.80, 320.0), prop = `prop_stat_pack_01` },
		{ id = 'zonah_med', category = 'medical', coords = vec4(-453.21, -339.68, 34.36, 80.0), prop = `prop_stat_pack_01` },

		-- Ammo
		{ id = 'ammu_lamesa', category = 'ammo', coords = vec4(844.12, -1034.86, 28.19, 0.0), prop = `prop_box_ammo07a` },
		{ id = 'ammu_pillbox', category = 'ammo', coords = vec4(16.98, -1114.42, 29.79, 250.0), prop = `prop_box_ammo07a` },
		{ id = 'ammu_cypress', category = 'ammo', coords = vec4(813.67, -2155.13, 29.62, 0.0), prop = `prop_box_ammo03a` },

		-- Tools
		{ id = 'lsc_lamesa', category = 'tool', coords = vec4(726.55, -1071.72, 28.31, 90.0), prop = `prop_toolchest_01` },
		{ id = 'lsc_burton', category = 'tool', coords = vec4(-339.48, -131.62, 39.01, 250.0), prop = `prop_tool_box_04` },

		-- Junk / civilian crates
		{ id = 'legion_crate', category = 'crate', coords = vec4(167.21, -1003.48, 29.35, 160.0), prop = `prop_cs_cardbox_01` },
		{ id = 'docks_crate', category = 'crate', coords = vec4(1027.84, -2977.41, 5.90, 175.0), prop = `prop_box_wood02a` },
		{ id = 'grove_crate', category = 'crate', coords = vec4(-47.12, -1758.64, 29.42, 50.0), prop = `prop_cs_cardbox_01` },
	},
}
