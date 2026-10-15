return {
	['testburger'] = {
		label = 'Test Burger',
		weight = 220,
		degrade = 60,
		client = {
			image = 'burger_chicken.png',
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			export = 'ox_inventory_examples.testburger'
		},
		server = {
			export = 'ox_inventory_examples.testburger',
			test = 'what an amazingly delicious burger, amirite?'
		},
		buttons = {
			{
				label = 'Lick it',
				action = function(slot)
					print('You licked the burger')
				end
			},
			{
				label = 'Squeeze it',
				action = function(slot)
					print('You squeezed the burger :(')
				end
			},
			{
				label = 'What do you call a vegan burger?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('A misteak.')
				end
			},
			{
				label = 'What do frogs like to eat with their hamburgers?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('French flies.')
				end
			},
			{
				label = 'Why were the burger and fries running?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('Because they\'re fast food.')
				end
			}
		},
		consume = 0.3
	},

	['bandage'] = {
		label = 'Bandage',
		weight = 115,
		client = {
			anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
			prop = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
			disable = { move = true, car = true, combat = true },
			usetime = 2500,
		}
	},

	['black_money'] = {
		label = 'Dirty Money',
	},

	['burger'] = {
		label = 'Burger',
		weight = 220,
		client = {
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			notification = 'You ate a delicious burger'
		},
	},

	['sprunk'] = {
		label = 'Sprunk',
		weight = 350,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
			usetime = 2500,
			notification = 'You quenched your thirst with a sprunk'
		}
	},

	['parachute'] = {
		label = 'Parachute',
		weight = 8000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 1500
		}
	},

	['garbage'] = {
		label = 'Garbage',
	},

	['paperbag'] = {
		label = 'Paper Bag',
		weight = 1,
		stack = false,
		close = false,
		consume = 0
	},

	['identification'] = {
		label = 'Identification',
		client = {
			image = 'card_id.png'
		}
	},

	['panties'] = {
		label = 'Knickers',
		weight = 10,
		consume = 0,
		client = {
			status = { thirst = -100000, stress = -25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
			usetime = 2500,
		}
	},

	['lockpick'] = {
		label = 'Lockpick',
		weight = 160,
	},

	['blueprint_bandage'] = {
		label = 'Bandage Blueprint',
		weight = 10,
		stack = true,
	},

	['blueprint_medikit'] = {
		label = 'Medikit Blueprint',
		weight = 10,
		stack = true,
	},

	['blueprint_ammo-9'] = {
		label = '9mm Blueprint',
		weight = 10,
		stack = true,
	},

	['blueprint_ammo-rifle'] = {
		label = 'Rifle Ammo Blueprint',
		weight = 10,
		stack = true,
	},

	['gps'] = {
		label = 'GPS',
		weight = 200,
		stack = false,
		close = false,
		consume = 0,
		-- Goes in the wearables watch slot and keeps the minimap on
		wearable = 'watch',
		client = {
			event = 'ruck_hud:useGPS',
		},
	},

	['backpack'] = {
		label = 'Backpack',
		weight = 1500,
		stack = false,
		close = false,
		consume = 0,
		wearable = 'backpack',
		description = 'A proper pack. Wear it in the backpack slot.',
	},

	-- Plate carriers for the wearables armour slot: the armour is the plates inside
	-- (data/gear.lua). Open one from the Wearables tab to put plates in.
	['platecarrier'] = {
		label = 'Plate Carrier',
		weight = 2000,
		stack = false,
		close = false,
		consume = 0,
		wearable = 'armour',
		description = 'Three plate pockets: kevlar (17 each), ceramic (25) or steel (34). Wear it in the armour slot and open it from Wearables.',
		client = {
			image = 'armour.png',
		},
	},

	['phone'] = {
		label = 'Phone',
		weight = 190,
		stack = false,
		consume = 0,
		client = {
			add = function(total)
				if total > 0 then
					pcall(function() return exports.npwd:setPhoneDisabled(false) end)
				end
			end,

			remove = function(total)
				if total < 1 then
					pcall(function() return exports.npwd:setPhoneDisabled(true) end)
				end
			end
		}
	},

	['tablet'] = {
		label = 'Tablet',
		weight = 190,
		stack = false,
		consume = 0,
	},

	['money'] = {
		label = 'Money',
	},

	['mustard'] = {
		label = 'Mustard',
		weight = 500,
		client = {
			status = { hunger = 25000, thirst = 25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
			usetime = 2500,
			notification = 'You.. drank mustard'
		}
	},

	['water'] = {
		label = 'Water',
		weight = 500,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 2500,
			cancel = true,
			notification = 'You drank some refreshing water'
		}
	},

	['radio'] = {
		label = 'Radio',
		weight = 1000,
		stack = false,
		allowArmed = true
	},

	['armour'] = {
		label = 'Bulletproof Vest',
		weight = 3000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 3500
		}
	},

	['clothing'] = {
		label = 'Clothing',
		consume = 0,
	},

	['mastercard'] = {
		label = 'Fleeca Card',
		stack = false,
		weight = 10,
		client = {
			image = 'card_bank.png'
		}
	},

	['scrapmetal'] = {
		label = 'Scrap Metal',
		weight = 80,
	},

	["alive_chicken"] = {
		label = "Living chicken",
		weight = 1,
		stack = true,
		close = true,
	},

	["blowpipe"] = {
		label = "Blowtorch",
		weight = 2,
		stack = true,
		close = true,
	},

	["bread"] = {
		label = "Bread",
		weight = 1,
		stack = true,
		close = true,
	},

	["cannabis"] = {
		label = "Cannabis",
		weight = 3,
		stack = true,
		close = true,
	},

	["carokit"] = {
		label = "Body Kit",
		weight = 3,
		stack = true,
		close = true,
	},

	["carotool"] = {
		label = "Tools",
		weight = 2,
		stack = true,
		close = true,
	},

	["clothe"] = {
		label = "Cloth",
		weight = 1,
		stack = true,
		close = true,
	},

	["copper"] = {
		label = "Copper",
		weight = 1,
		stack = true,
		close = true,
	},

	["cutted_wood"] = {
		label = "Cut wood",
		weight = 1,
		stack = true,
		close = true,
	},

	["diamond"] = {
		label = "Diamond",
		weight = 1,
		stack = true,
		close = true,
	},

	["essence"] = {
		label = "Gas",
		weight = 1,
		stack = true,
		close = true,
	},

	["fabric"] = {
		label = "Fabric",
		weight = 1,
		stack = true,
		close = true,
	},

	["fish"] = {
		label = "Fish",
		weight = 1,
		stack = true,
		close = true,
	},

	["fixkit"] = {
		label = "Repair Kit",
		weight = 3,
		stack = true,
		close = true,
	},

	["fixtool"] = {
		label = "Repair Tools",
		weight = 2,
		stack = true,
		close = true,
	},

	["gazbottle"] = {
		label = "Gas Bottle",
		weight = 2,
		stack = true,
		close = true,
	},

	["gold"] = {
		label = "Gold",
		weight = 1,
		stack = true,
		close = true,
	},

	["iron"] = {
		label = "Iron",
		weight = 1,
		stack = true,
		close = true,
	},

	["marijuana"] = {
		label = "Marijuana",
		weight = 2,
		stack = true,
		close = true,
	},

	["medikit"] = {
		label = "Medikit",
		weight = 2,
		stack = true,
		close = true,
	},

	["packaged_chicken"] = {
		label = "Chicken fillet",
		weight = 1,
		stack = true,
		close = true,
	},

	["packaged_plank"] = {
		label = "Packaged wood",
		weight = 1,
		stack = true,
		close = true,
	},

	["petrol"] = {
		label = "Oil",
		weight = 1,
		stack = true,
		close = true,
	},

	["petrol_raffin"] = {
		label = "Processed oil",
		weight = 1,
		stack = true,
		close = true,
	},

	["slaughtered_chicken"] = {
		label = "Slaughtered chicken",
		weight = 1,
		stack = true,
		close = true,
	},

	["stone"] = {
		label = "Stone",
		weight = 1,
		stack = true,
		close = true,
	},

	["washed_stone"] = {
		label = "Washed stone",
		weight = 1,
		stack = true,
		close = true,
	},

	["wood"] = {
		label = "Wood",
		weight = 1,
		stack = true,
		close = true,
	},

	["wool"] = {
		label = "Wool",
		weight = 1,
		stack = true,
		close = true,
	},

	-- Gear (modules/gear, data/gear.lua): bags, masks, plate carriers and plates, the holster.
	['backpack_small'] = {
		label = 'Small Backpack',
		weight = 600,
		stack = false,
		close = false,
		consume = 0,
		wearable = 'backpack',
		description = 'Room for a few things. Wear it in the backpack slot.',
	},

	['duffel_bag'] = {
		label = 'Duffel Bag',
		weight = 1500,
		stack = false,
		close = false,
		consume = 0,
		wearable = 'backpack',
		description = 'Big enough for a job. Wear it in the backpack slot.',
		client = { image = 'bag.png' },
	},

	['respirator'] = {
		label = 'Respirator',
		weight = 400,
		stack = false,
		close = false,
		consume = 0,
		wearable = 'mask',
		description = 'Wear it in the mask slot: tear gas and BZ cannot get to you.',
	},

	['gasmask'] = {
		label = 'CBRN Mask',
		weight = 1000,
		stack = false,
		close = false,
		consume = 0,
		wearable = 'mask',
		description = 'Wear it in the mask slot: tear gas and BZ cannot get to you.',
	},

	['rebreather'] = {
		label = 'Rebreather',
		weight = 1200,
		stack = false,
		close = false,
		consume = 0,
		wearable = 'mask',
		description = 'Wear it in the mask slot: three minutes of air under water, refilling at the surface.',
	},

	['platecarrier_pd'] = {
		label = 'Police Plate Carrier',
		weight = 1800,
		stack = false,
		close = false,
		consume = 0,
		wearable = 'armour',
		description = 'Two plate pockets: kevlar (25 each) or ceramic (35). Wear it in the armour slot and open it from Wearables.',
	},

	['platecarrier_makeshift'] = {
		label = 'Makeshift Plate Carrier',
		weight = 1500,
		stack = false,
		close = false,
		consume = 0,
		wearable = 'armour',
		description = 'Two plate pockets, rough: kevlar (12 each) or steel (20). Wear it in the armour slot and open it from Wearables.',
	},

	['platecarrier_heavy'] = {
		label = 'Heavy Plate Carrier',
		weight = 3200,
		stack = false,
		close = false,
		consume = 0,
		wearable = 'armour',
		description = 'Three plate pockets: ceramic (30 each) or steel (34). Wear it in the armour slot and open it from Wearables.',
	},

	['plate_kevlar'] = {
		label = 'Kevlar Plate',
		weight = 600,
		stack = false,
		close = false,
		consume = 0,
		description = 'Light. Goes in a plate carrier; what it gives depends on the carrier. Worn down by hits.',
	},

	['plate_ceramic'] = {
		label = 'Ceramic Plate',
		weight = 1400,
		stack = false,
		close = false,
		consume = 0,
		description = 'Goes in a plate carrier; what it gives depends on the carrier. Worn down by hits.',
	},

	['plate_steel'] = {
		label = 'Steel Plate',
		weight = 2600,
		stack = false,
		close = false,
		consume = 0,
		description = 'Heavy. Goes in a plate carrier; what it gives depends on the carrier. Worn down by hits.',
	},

	['holster'] = {
		label = 'Holster',
		weight = 300,
		stack = false,
		close = false,
		consume = 0,
		wearable = 'holster',
		description = 'Wear it in the holster slot: pistols draw fast from the hip, and it shows at the small of your back (on a woman, the right hip). Right-click it for a waistband holster or a hip holster.',
	},
}
