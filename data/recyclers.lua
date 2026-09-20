-- Rust-style recyclers: drop items in, toggle ON, outputs appear on the right.
-- Add/edit locations and recipes here. Unknown items are skipped (left in input).

return {
	-- Recycle every weapon into scrap based on item weight
	recycleWeapons = true,
	-- Recycle magazines, empty mags, and loose bullets
	recycleAmmo = true,

	-- Per-item overrides / extras. consume defaults to 1.
	-- duration is milliseconds per cycle (Rust is ~5s).
	recipes = {
		lockpick = { duration = 4000, output = { scrapmetal = 1 } },
		phone = { duration = 6000, output = { scrapmetal = 3 } },
		radio = { duration = 6000, output = { scrapmetal = 2 } },
		armour = { duration = 8000, output = { scrapmetal = 5 } },

		['ammo-9'] = { duration = 4000, output = { scrapmetal = 2 } },
		['ammo-rifle'] = { duration = 4000, output = { scrapmetal = 2 } },
		['ammo-rifle2'] = { duration = 4000, output = { scrapmetal = 2 } },
		['ammo-45'] = { duration = 4000, output = { scrapmetal = 2 } },
		['ammo-38'] = { duration = 4000, output = { scrapmetal = 2 } },
		['ammo-44'] = { duration = 4000, output = { scrapmetal = 2 } },
		['ammo-50'] = { duration = 4000, output = { scrapmetal = 2 } },
		['ammo-22'] = { duration = 4000, output = { scrapmetal = 1 } },
		['ammo-shotgun'] = { duration = 3500, output = { scrapmetal = 1 } },

		['empty_9_magazine'] = { duration = 3000, output = { scrapmetal = 1 } },
		['empty_rifle_magazine'] = { duration = 3000, output = { scrapmetal = 1 } },
		['empty_rifle2_magazine'] = { duration = 3000, output = { scrapmetal = 1 } },
		['empty_45_magazine'] = { duration = 3000, output = { scrapmetal = 1 } },
		['empty_38_magazine'] = { duration = 3000, output = { scrapmetal = 1 } },
		['empty_shotgun_shell'] = { duration = 2500, output = { scrapmetal = 1 } },

		-- Loose rounds: 5 bullets -> 1 scrap
		['bullet-9'] = { duration = 2500, consume = 5, output = { scrapmetal = 1 } },
		['bullet-rifle'] = { duration = 2500, consume = 5, output = { scrapmetal = 1 } },
		['bullet-rifle2'] = { duration = 2500, consume = 5, output = { scrapmetal = 1 } },
		['bullet-45'] = { duration = 2500, consume = 5, output = { scrapmetal = 1 } },
		['bullet-38'] = { duration = 2500, consume = 5, output = { scrapmetal = 1 } },
		['bullet-shotgun'] = { duration = 2500, consume = 4, output = { scrapmetal = 1 } },
	},

	locations = {
		{
			id = 'ls_recycling',
			label = 'Recycler',
			-- La Puerta recycling plant
			coords = vec4(-344.66, -1567.38, 25.23, 58.0),
			prop = `prop_recyclebin_05_a`,
			distance = 3.0,
			blip = { id = 365, colour = 2, scale = 0.7 },
		},
		{
			id = 'senora_scrap',
			label = 'Recycler',
			-- Grand Senora Desert scrapyard
			coords = vec4(2338.41, 3130.22, 48.21, 80.0),
			prop = `prop_recyclebin_05_a`,
			distance = 3.0,
			blip = { id = 365, colour = 2, scale = 0.7 },
		},
	},
}
