-- Use an empty magazine to pack it with matching loose rounds.
-- chain = keep packing until cancelled, out of mags, or out of bullets.

return {
	chain = true,

	empty_9_magazine = {
		ammo = '9mm',
		bullets = 'bullet-9',
		count = 17,
		give = 'ammo-9',
		duration = 3000,
	},
	empty_45_magazine = {
		ammo = '.45',
		bullets = 'bullet-45',
		count = 18,
		give = 'ammo-45',
		duration = 3000,
	},
	empty_44_magazine = {
		ammo = '.44',
		bullets = 'bullet-44',
		count = 6,
		give = 'ammo-44',
		duration = 2500,
	},
	empty_38_magazine = {
		ammo = '.38',
		bullets = 'bullet-38',
		count = 7,
		give = 'ammo-38',
		duration = 2500,
	},
	empty_22_magazine = {
		ammo = '.22',
		bullets = 'bullet-22',
		count = 10,
		give = 'ammo-22',
		duration = 2500,
	},
	empty_50_magazine = {
		ammo = '.50 AE',
		bullets = 'bullet-50',
		count = 9,
		give = 'ammo-50',
		duration = 3000,
	},
	empty_rifle_magazine = {
		ammo = '5.56',
		bullets = 'bullet-rifle',
		count = 30,
		give = 'ammo-rifle',
		duration = 4000,
	},
	empty_rifle2_magazine = {
		ammo = '7.62',
		bullets = 'bullet-rifle2',
		count = 30,
		give = 'ammo-rifle2',
		duration = 4000,
	},
	empty_sniper_magazine = {
		ammo = '7.62x51',
		bullets = 'bullet-sniper',
		count = 10,
		give = 'ammo-sniper',
		duration = 3500,
	},
	empty_heavysniper_magazine = {
		ammo = '.50 BMG',
		bullets = 'bullet-heavysniper',
		count = 6,
		give = 'ammo-heavysniper',
		duration = 4000,
	},
	empty_shotgun_shell = {
		ammo = '12 Gauge',
		bullets = 'bullet-shotgun',
		count = 1,
		give = 'ammo-shotgun',
		duration = 1500,
	},
}
