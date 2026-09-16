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
}
