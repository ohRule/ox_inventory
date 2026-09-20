--[[
  Rust-style tech tree crafting.
  Roots have no previousItem (unlockItem optional). Children stay locked until the parent
  recipe is unlocked, then consume unlockItem (blueprint) or unlockScrap to unlock them.
  Research tables consume 1 of the item placed on the table + researchScrap (defaults to unlockScrap).

  Bench fields:
    locations = { { coords = vec3(), heading = 0.0, prop? } }
    prop      = 'model'   -- spawned at each location
    research  = { label, prop, locations, blip? }  -- optional research table
    tier      = 1
    groups/jobs = { job = minGrade }

  Recipe fields:
    previousItem  = 'item_name'
    unlockItem    = { name = 'blueprint_x', count = 1 }
    unlockScrap   = 20   -- alternative workbench unlock cost
    researchScrap = 20   -- research table cost (defaults to unlockScrap)
    ingredients, duration, count, tier
]]

return {
	requirePreviousItemUnlocked = true,
	unlockScrapItem = 'scrapmetal',

	{
		name = 'workbench_garage',
		label = 'Workbench',
		tier = 1,
		prop = 'gr_prop_gr_bench_02a',
		locations = {
			{ coords = vec3(717.24, -1088.91, 22.36), heading = 90.0 },
		},
		research = {
			label = 'Research Table',
			prop = 'gr_prop_gr_bench_04b',
			locations = {
				{ coords = vec3(717.24, -1092.4, 22.36), heading = 90.0 },
			},
			blip = { id = 566, colour = 46, scale = 0.7 },
		},
		items = {
			-- Root: always available
			{ name = 'lockpick', tier = 1, ingredients = { scrapmetal = 5 }, duration = 5000, count = 1 },
			-- Branch 1
			{ name = 'bandage', tier = 1, previousItem = 'lockpick', unlockItem = { name = 'blueprint_bandage', count = 1 }, unlockScrap = 15, ingredients = { clothe = 2 }, duration = 3000, count = 1 },
			{ name = 'medikit', tier = 1, previousItem = 'bandage', unlockItem = { name = 'blueprint_medikit', count = 1 }, unlockScrap = 30, ingredients = { scrapmetal = 8, bandage = 2 }, duration = 5000, count = 1 },
			-- Branch 2
			{ name = 'ammo-9', tier = 1, previousItem = 'lockpick', unlockItem = { name = 'blueprint_ammo-9', count = 1 }, unlockScrap = 20, ingredients = { scrapmetal = 4 }, duration = 4000, count = 12 },
			{ name = 'ammo-rifle', tier = 1, previousItem = 'ammo-9', unlockItem = { name = 'blueprint_ammo-rifle', count = 1 }, unlockScrap = 40, ingredients = { scrapmetal = 8 }, duration = 5000, count = 12 },
		},
		blip = { id = 566, colour = 31, scale = 0.8 },
	},
}
