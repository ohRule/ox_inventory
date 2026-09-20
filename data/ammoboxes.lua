-- Use an ammo box to unpack loose rounds (not loaded magazines).
-- duration is milliseconds. give/count is what the player receives.
-- chain = keep unpacking the same box type until cancelled or you run out.

return {
	chain = true,

	ammo_box_9 = {
		label = '9mm Ammo Box',
		ammo = '9mm',
		weight = 500,
		duration = 6000,
		give = 'bullet-9',
		count = 50,
	},
	ammo_box_45 = {
		label = '.45 Ammo Box',
		ammo = '.45',
		weight = 500,
		duration = 6000,
		give = 'bullet-45',
		count = 50,
	},
	ammo_box_38 = {
		label = '.38 Ammo Box',
		ammo = '.38',
		weight = 450,
		duration = 6000,
		give = 'bullet-38',
		count = 50,
	},
	ammo_box_rifle = {
		label = '5.56 Ammo Box',
		ammo = '5.56',
		weight = 700,
		duration = 7000,
		give = 'bullet-rifle',
		count = 60,
	},
	ammo_box_rifle2 = {
		label = '7.62 Ammo Box',
		ammo = '7.62',
		weight = 800,
		duration = 7000,
		give = 'bullet-rifle2',
		count = 60,
	},
	ammo_box_shotgun = {
		label = '12 Gauge Ammo Box',
		ammo = '12 Gauge',
		weight = 600,
		duration = 6000,
		give = 'bullet-shotgun',
		count = 24,
	},
	ammo_box_sniper = {
		label = '7.62x51 Ammo Box',
		ammo = '7.62x51',
		weight = 650,
		duration = 7000,
		give = 'bullet-sniper',
		count = 20,
	},
}
