-- Always-available quick craft recipes (separate from bench crafting in data/crafting.lua)
return {
	{
		name = 'bandage',
		category = 'medical',
		ingredients = {
			clothe = 5,
			water = 2,
		},
		duration = 5000,
		count = 10,
	},
	{
		name = 'lockpick',
		category = 'tools',
		ingredients = {
			scrapmetal = 5,
		},
		duration = 3000,
		count = 1,
	},
	-- Load empty magazines with loose rounds (1 item = 1 loaded mag)
	{
		name = 'ammo-rifle',
		label = 'Load 5.56 Magazine',
		category = 'ammo',
		ingredients = {
			['empty_rifle_magazine'] = 1,
			['bullet-rifle'] = 30,
		},
		duration = 2000,
		count = 1,
	},
	{
		name = 'ammo-rifle2',
		label = 'Load 7.62 Magazine',
		category = 'ammo',
		ingredients = {
			['empty_rifle2_magazine'] = 1,
			['bullet-rifle2'] = 30,
		},
		duration = 2000,
		count = 1,
	},
	{
		name = 'ammo-9',
		label = 'Load 9mm Magazine',
		category = 'ammo',
		ingredients = {
			['empty_9_magazine'] = 1,
			['bullet-9'] = 17,
		},
		duration = 2000,
		count = 1,
	},
	{
		name = 'ammo-45',
		label = 'Load .45 Magazine',
		category = 'ammo',
		ingredients = {
			['empty_45_magazine'] = 1,
			['bullet-45'] = 18,
		},
		duration = 2000,
		count = 1,
	},
	{
		name = 'ammo-44',
		label = 'Load .44 Magazine',
		category = 'ammo',
		ingredients = {
			['empty_44_magazine'] = 1,
			['bullet-44'] = 6,
		},
		duration = 2000,
		count = 1,
	},
	{
		name = 'ammo-38',
		label = 'Load .38 Magazine',
		category = 'ammo',
		ingredients = {
			['empty_38_magazine'] = 1,
			['bullet-38'] = 7,
		},
		duration = 2000,
		count = 1,
	},
	{
		name = 'ammo-22',
		label = 'Load .22 Magazine',
		category = 'ammo',
		ingredients = {
			['empty_22_magazine'] = 1,
			['bullet-22'] = 10,
		},
		duration = 2000,
		count = 1,
	},
	{
		name = 'ammo-50',
		label = 'Load .50 AE Magazine',
		category = 'ammo',
		ingredients = {
			['empty_50_magazine'] = 1,
			['bullet-50'] = 9,
		},
		duration = 2000,
		count = 1,
	},
	{
		name = 'ammo-sniper',
		label = 'Load 7.62x51 Magazine',
		category = 'ammo',
		ingredients = {
			['empty_sniper_magazine'] = 1,
			['bullet-sniper'] = 10,
		},
		duration = 2000,
		count = 1,
	},
	{
		name = 'ammo-heavysniper',
		label = 'Load .50 BMG Magazine',
		category = 'ammo',
		ingredients = {
			['empty_heavysniper_magazine'] = 1,
			['bullet-heavysniper'] = 6,
		},
		duration = 2000,
		count = 1,
	},
	{
		name = 'ammo-shotgun',
		label = 'Reload 12 Gauge Shell',
		category = 'ammo',
		ingredients = {
			['empty_shotgun_shell'] = 1,
			['bullet-shotgun'] = 1,
		},
		duration = 1500,
		count = 1,
	},
}
