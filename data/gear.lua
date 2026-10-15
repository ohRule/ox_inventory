-- Gear worn in the Wearables slots (modules/gear). Which slot an item goes in is its
-- `wearable` in data/items.lua; this file says what it does there.

return {
	-- What a worn item shows on the character. component (0-11) or prop (0-7) is the
	-- clothing it's shown as; male / female are { drawable, texture } on the freemode
	-- man and woman. collection = an add-on clothing set (the drawable counted within
	-- the set); fallback = { drawable, texture } of the game's own while the set isn't
	-- there. fit = a size table in data/gearfit.lua (if there is one): the look in the
	-- size that clears the clothes on. Your own clothes come back when it comes off.
	looks = {
		-- The backpack is an add-on set (stream/): colours 0 black, 1 yellow chevrons,
		-- 2 red chevrons, 3 white, 4 tan, 5 olive. Without it, the game's packs.
		backpack_small = { component = 5, fit = 'bag',
			male = { 0, 5, collection = 'mp_m_ruck_bags', fallback = { 52, 0 } },
			female = { 0, 5, collection = 'mp_f_ruck_bags', fallback = { 52, 0 } } },
		backpack = { component = 5, fit = 'bag',
			male = { 0, 0, collection = 'mp_m_ruck_bags', fallback = { 31, 0 } },
			female = { 0, 0, collection = 'mp_f_ruck_bags', fallback = { 31, 0 } } },
		duffel_bag = { component = 5, male = { 45, 0 }, female = { 45, 0 } },

		-- Masks (one list for men and women): 36 a half-face respirator, 38 a full-face
		-- mask with a visor, 175 goggles and a breathing mask.
		respirator = { component = 1, male = { 36, 0 }, female = { 36, 0 } },
		gasmask = { component = 1, male = { 38, 0 }, female = { 38, 0 } },
		rebreather = { component = 1, male = { 175, 0 }, female = { 175, 0 } },

		-- Body armour: the tan plate carriers (all four look the same for now).
		platecarrier = { component = 9, male = { 15, 0 }, female = { 17, 0 } },
		platecarrier_pd = { component = 9, male = { 15, 0 }, female = { 17, 0 } },
		platecarrier_makeshift = { component = 9, male = { 15, 0 }, female = { 17, 0 } },
		platecarrier_heavy = { component = 9, male = { 15, 0 }, female = { 17, 0 } },
	},

	-- Gear is never anyone's own clothes. bare = what a part of the character shows with
	-- nothing on it (a drawable, or male / female). gearOnly = the add-on sets only gear
	-- uses. One of those on a character whose gear isn't worn there (a clothing shop saved
	-- it into their clothes) comes off, and taking gear off never puts one back; nor the
	-- very look the gear puts on.
	bare = { [1] = 0, [5] = 0, [7] = 0, [8] = { male = 15, female = 14 }, [9] = 0 },
	gearOnly = { 'mp_m_ruck_bags', 'mp_f_ruck_bags', 'mp_m_ruck_holster', 'mp_f_ruck_holster', 'mp_m_ruck_waistband' },

	-- Bags: what fits inside (weight in grams). Worn in the backpack slot, the player
	-- can carry that much more. A bag keeps the size it was made with.
	bags = {
		backpack_small = { slots = 10, weight = 10000 },
		backpack = { slots = 20, weight = 20000 },
		duffel_bag = { slots = 30, weight = 30000 },
	},

	-- Armour. A carrier in the armour slot holds `plates` plates (open it from the
	-- Wearables tab); the armour is what its plates give, each worn down by hits until
	-- it breaks. With no carrier on, there's no armour (onlyFromCarrier). A carrier's own
	-- `values` are the plates it takes and what each gives in it; without them, every
	-- plate below at its value there.
	carriers = {
		platecarrier = { plates = 3 },
		platecarrier_pd = { plates = 2, values = { plate_kevlar = 25, plate_ceramic = 35 } },
		platecarrier_makeshift = { plates = 2, values = { plate_kevlar = 12, plate_steel = 20 } },
		platecarrier_heavy = { plates = 3, values = { plate_ceramic = 30, plate_steel = 34 } },
	},
	plates = {
		plate_kevlar = 17,
		plate_ceramic = 25,
		plate_steel = 34,
	},
	onlyFromCarrier = true,

	-- Masks. A respirator in the mask slot keeps gas (tear gas, BZ, smoke) off; a
	-- rebreather gives this many seconds of air under water, refilling at the surface.
	respirators = {
		respirator = true,
		gasmask = true,
	},
	rebreathers = {
		rebreather = 180,
	},

	-- Holsters: styles picked from the item's right-click menu (saved on the item). A
	-- style is the clothing shown with a pistol holstered and with the holster empty
	-- (drawn, or no pistol on you). A worn holster also draws and holsters pistols the
	-- police way, fast from the hip (modules/weapon/client.lua).
	-- The game's only holsters are the Doomsday Heist's, in the undershirt slot
	-- (component 8): the right-hip holster (christmas2017 8) and a duty belt (0), each
	-- with a pistol in it. The empty ones are those models with the pistol taken out,
	-- an add-on set (stream/, mp_*_ruck_holster): without it the holster comes off while
	-- the pistol's out. The duty belt isn't offered; a holster
	-- set to it shows the first style.
	-- A style (or one of its looks) with its own component is shown on that one instead.
	-- The waistband holster (the first, so a holster with no style picked shows it) is the
	-- fdg pack's, at the small of the back, in the accessories slot (component 7: it takes
	-- the place of a chain or tie, not the undershirt): an add-on set (stream/,
	-- mp_m_ruck_waistband), 0 with its pistol, 1 empty (the pistol taken out). Men only:
	-- a woman's shows the hip holster.
	holsters = {
		holster = {
			component = 8,
			styles = {
				{ id = 'waistband', label = 'Waistband holster', component = 7,
					male = { holstered = { 0, 0, collection = 'mp_m_ruck_waistband' }, empty = { 1, 0, collection = 'mp_m_ruck_waistband' } },
					female = { holstered = { 8, 0, collection = 'mp_f_christmas2017', component = 8 }, empty = { 0, 0, collection = 'mp_f_ruck_holster', component = 8 } } },
				{ id = 'hip', label = 'Hip holster',
					male = { holstered = { 8, 0, collection = 'mp_m_christmas2017' }, empty = { 0, 0, collection = 'mp_m_ruck_holster' } },
					female = { holstered = { 8, 0, collection = 'mp_f_christmas2017' }, empty = { 0, 0, collection = 'mp_f_ruck_holster' } } },
			},
		},
	},
}
