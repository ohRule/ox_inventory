-- Job loadouts claimed from a targeted vehicle.
-- Each kit is a full replacement: taking another kit returns the current one first.
-- Loadout items are tagged and stripped on return, logout, and relog.

return {
	-- How close the player must stand to the vehicle
	distance = 2.5,

	-- Spawn names (or hashes) that show the loadout target option.
	-- A kit can override with its own `models`, or set models = false for any vehicle.
	models = {
		'police', 'police2', 'police3', 'police4',
		'sheriff', 'sheriff2', 'pranger',
		'policeb', 'riot', 'fbi', 'fbi2',
		'ambulance',
	},

	-- Optional plates (trimmed, case-insensitive). Leave nil to allow any plate on the models above.
	-- plates = { 'PD 123', 'EMS 1' },

	-- Used only when `models` is nil. 18 = emergency.
	-- classes = { 18 },

	-- Vehicle armouries. Stock is unique per plate (this car), not shared across the model.
	armouries = {
		{
			id = 'police',
			label = 'Vehicle Armoury',
			description = 'Take or return spare equipment',
			icon = 'warehouse',
			groups = shared.police,
			models = {
				'police', 'police2', 'police3', 'police4',
				'sheriff', 'sheriff2', 'pranger',
				'policeb', 'riot', 'fbi', 'fbi2',
			},
			slots = 32,
			maxWeight = 80000,
			items = {
				{ name = 'WEAPON_PISTOL', count = 4, metadata = { registered = true, serial = 'POL' } },
				{ name = 'ammo-9', count = 12 },
				{ name = 'WEAPON_STUNGUN', count = 4, metadata = { registered = true, serial = 'POL' } },
				{ name = 'WEAPON_NIGHTSTICK', count = 4 },
				{ name = 'WEAPON_FLASHLIGHT', count = 4 },
				{ name = 'WEAPON_CARBINERIFLE', count = 2, metadata = { registered = true, serial = 'POL' } },
				{ name = 'ammo-rifle', count = 6 },
				{ name = 'armour', count = 6 },
			},
		},
		{
			id = 'ambulance',
			label = 'Medical Cabinet',
			description = 'Take or return medical supplies',
			icon = 'suitcase-medical',
			groups = { ambulance = 0 },
			models = { 'ambulance' },
			slots = 8,
			maxWeight = 40000,
			items = {
				{ name = 'medikit', count = 8 },
				{ name = 'bandage', count = 20 },
			},
		},
	},

	kits = {
		{
			id = 'police_standard',
			label = 'Standard Issue',
			description = 'Pistol, stun gun, baton, and armour',
			icon = 'handcuffs',
			groups = shared.police,
			models = {
				'police', 'police2', 'police3', 'police4',
				'sheriff', 'sheriff2', 'pranger',
				'policeb', 'riot', 'fbi', 'fbi2',
			},
			items = {
				{ name = 'WEAPON_PISTOL', count = 1, metadata = { registered = true } },
				{ name = 'ammo-9', count = 3 },
				{ name = 'WEAPON_STUNGUN', count = 1, metadata = { registered = true } },
				{ name = 'WEAPON_NIGHTSTICK', count = 1 },
				{ name = 'WEAPON_FLASHLIGHT', count = 1 },
				{ name = 'armour', count = 1 },
			},
		},
		{
			id = 'police_rifle',
			label = 'Rifle Issue',
			description = 'Standard kit plus a carbine',
			icon = 'gun',
			groups = { police = 3, sheriff = 3 },
			models = {
				'police', 'police2', 'police3', 'police4',
				'sheriff', 'sheriff2', 'pranger',
				'riot',
			},
			items = {
				{ name = 'WEAPON_PISTOL', count = 1, metadata = { registered = true } },
				{ name = 'ammo-9', count = 3 },
				{ name = 'WEAPON_STUNGUN', count = 1, metadata = { registered = true } },
				{ name = 'WEAPON_NIGHTSTICK', count = 1 },
				{ name = 'WEAPON_FLASHLIGHT', count = 1 },
				{ name = 'WEAPON_CARBINERIFLE', count = 1, metadata = { registered = true } },
				{ name = 'ammo-rifle', count = 3 },
				{ name = 'armour', count = 1 },
			},
		},
		{
			id = 'ambulance_standard',
			label = 'EMS Kit',
			description = 'Medkits and bandages',
			icon = 'suitcase-medical',
			groups = { ambulance = 0 },
			models = { 'ambulance' },
			items = {
				{ name = 'medikit', count = 5 },
				{ name = 'bandage', count = 10 },
			},
		},
	},
}
