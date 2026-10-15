if not lib then return end

-- Gear worn in the Wearables slots (data/gear.lua), in the player's own game: what's
-- worn shown on the character (and taken off again, their own clothes back), the
-- armour a carrier's plates give, a respirator keeping gas off, a rebreather's air
-- under water, and a holster's look and style menu.

local Items = require 'modules.items.client'
local SLOT_IDS = require 'modules.wearables.shared'
local Config = lib.load('data.gear') or {}
local Fit = lib.load('data.gearfit')

local looks = Config.looks or {}
local carriers = Config.carriers or {}
local holsters = Config.holsters or {}
local respirators = Config.respirators or {}
local rebreathers = Config.rebreathers or {}
local bare = Config.bare or {}
local gearOnly = {}
for _, set in ipairs(Config.gearOnly or {}) do gearOnly[set:lower()] = true end

local MALE, FEMALE = `mp_m_freemode_01`, `mp_f_freemode_01`

local worn = {}    -- [zone] = the item in that Wearables slot
local on = {}      -- [zone] = the look put on for it
local restore = {} -- [zone] = what that part of the character was before

local function sexOf(ped)
	local model = GetEntityModel(ped)
	return model == MALE and 'male' or model == FEMALE and 'female' or nil
end

local function isDown(ped)
	local state = LocalPlayer.state
	return IsEntityDead(ped) or state.isDead or state.dead or state.knockedout
end

---------------------------------------------------------------------------------------
-- Looks. A look is { drawable, texture } of the game's own clothes on `component`
-- (or `prop`), or with `collection`, of an add-on set: the drawable counted in the set.
---------------------------------------------------------------------------------------

-- Sizes (data/gearfit.lua): for each piece of the game's clothing in the slots that can
-- show through, the size of each fit that clears it, one character per number (0-9,
-- a-z). The biggest any piece on needs is worn; a bag also clears a carrier under it.
local FIT_SLOTS = { 4, 7, 8, 11 }

local function sizeIn(sizes, index)
	local c = type(sizes) == 'string' and index >= 0 and sizes:sub(index + 1, index + 1) or ''
	return c ~= '' and tonumber(c, 36) or 0
end

local function sizeNeeded(ped, sex, fit)
	local need = Fit and Fit.need and Fit.need[sex]
	local size = 0
	if not need then return 0 end

	for _, c in ipairs(FIT_SLOTS) do
		local set = (GetPedDrawableVariationCollectionName(ped, c) or ''):lower()
		local here = need[c] and need[c][set]
		local n = here and sizeIn(here[fit], GetPedDrawableVariationCollectionLocalIndex(ped, c) or -1) or 0
		if n > size then size = n end
	end

	return size
end

local function sizedLook(ped, sex, def, look)
	local set = Fit and Fit.sets and Fit.sets[sex] and Fit.sets[sex][def.fit]
	local sizes = Fit and Fit.sizes and Fit.sizes[sex] and Fit.sizes[sex][def.fit]
	if not set or not sizes then return end

	local size = sizeNeeded(ped, sex, def.fit)

	if def.fit == 'bag' and worn.armour and carriers[worn.armour.name] then
		local over = Fit.overVest and Fit.overVest[sex] and sizeIn(Fit.overVest[sex].full, 0) or 0
		if over > size then size = over end
	end

	size = math.min(size, #sizes)
	if size == 0 then return end

	local colour = look.collection and (look[2] or 0) or 0
	if not IsPedCollectionComponentVariationValid(ped, def.component, set, sizes[size], colour) then return end
	return { sizes[size], colour, collection = set, component = def.component }
end

local function resolve(def, look, ped)
	if look.collection and not IsPedCollectionComponentVariationValid(ped, def.component, look.collection, look[1], look[2] or 0) then
		look = look.fallback
		if not look then return end
	end

	return { look[1], look[2] or 0, collection = look.collection, component = def.component, prop = def.prop }
end

local pistolOut = false

local function hasPistol()
	for _, item in pairs(PlayerData.inventory or {}) do
		local data = type(item) == 'table' and item.name and Items[item.name]
		if data and data.weapon and data.hash and GetWeapontypeGroup(data.hash) == `GROUP_PISTOL` then return true end
	end
	return false
end

-- A holster's look: its style (picked from its menu, else the first), holstered with a
-- pistol on you and not in hand, otherwise empty (none if its set isn't there).
local function holsterLook(item, sex, ped)
	local def = holsters[item.name]
	local style = def.styles[1]

	for i = 1, #def.styles do
		if def.styles[i].id == item.metadata?.style then style = def.styles[i] break end
	end

	local looks = style and style[sex]
	if not looks then return end

	local look = (hasPistol() and not pistolOut) and looks.holstered or looks.empty
	-- A style, or one of its looks, can be on another component than the holster's own
	return look and resolve({ component = look.component or style.component or def.component }, look, ped)
end

---The look an item worn in `zone` should have now, or nil.
local function lookFor(zone)
	local item = worn[zone]
	if not item then return end

	local ped = cache.ped
	local sex = sexOf(ped)
	if not sex then return end

	if holsters[item.name] then return holsterLook(item, sex, ped) end

	local def = looks[item.name]
	local look = def and def[sex]
	if not look then return end

	return (def.fit and sizedLook(ped, sex, def, look)) or resolve(def, look, ped)
end

local function current(ped, look)
	if look.prop then
		return { GetPedPropIndex(ped, look.prop), GetPedPropTextureIndex(ped, look.prop), prop = look.prop }
	end
	return { GetPedDrawableVariation(ped, look.component), GetPedTextureVariation(ped, look.component), GetPedPaletteVariation(ped, look.component), component = look.component }
end

local function dress(ped, look)
	if look.prop then
		if look[1] < 0 then ClearPedProp(ped, look.prop) else SetPedPropIndex(ped, look.prop, look[1], look[2] or 0, true) end
	elseif look.collection then
		SetPedCollectionComponentVariation(ped, look.component, look.collection, look[1], look[2] or 0, 0)
	else
		SetPedComponentVariation(ped, look.component, look[1], look[2] or 0, look[3] or 0)
	end
end

-- The add-on set on a part of the character, lower case ('' for the game's own clothes)
local function collectionOn(ped, component)
	local set = GetPedDrawableVariationCollectionName(ped, component)
	return type(set) == 'string' and set:lower() or ''
end

local function wearing(ped, look)
	if look.prop then return GetPedPropIndex(ped, look.prop) == look[1] end
	if look.collection then
		return collectionOn(ped, look.component) == look.collection:lower()
			and GetPedDrawableVariationCollectionLocalIndex(ped, look.component) == look[1]
	end
	return GetPedDrawableVariation(ped, look.component) == look[1] and GetPedTextureVariation(ped, look.component) == (look[2] or 0)
end

-- What a part of the character shows with nothing on it (data/gear.lua bare), or nil
local function bareLook(component, ped)
	local b = bare[component]
	if type(b) == 'table' then b = b[sexOf(ped) or ''] end
	return b and { b, 0, 0, component = component } or nil
end

-- One of the sets only gear uses (data/gear.lua gearOnly)
local function gearOnlyOn(ped, component)
	return gearOnly[collectionOn(ped, component)] or false
end

-- The character's own clothes where a look goes, kept to put back when it comes off. A
-- gear set there, or the very look going on, is gear a clothing shop saved into their
-- clothes: that's nothing.
local function ownClothes(ped, look)
	if not look.prop and (gearOnlyOn(ped, look.component) or wearing(ped, look)) then
		local b = bareLook(look.component, ped)
		if b then return b end
	end
	return current(ped, look)
end

local function takeOff(zone)
	if restore[zone] then dress(cache.ped, restore[zone]) end
	restore[zone], on[zone] = nil, nil
end

local function putOn(zone, look)
	local ped = cache.ped
	-- Moving to another part of the character (a holster style on another component):
	-- what was there before comes back first
	if on[zone] and (on[zone].component ~= look.component or on[zone].prop ~= look.prop) then takeOff(zone) end
	if not restore[zone] then restore[zone] = ownClothes(ped, look) end
	dress(ped, look)
	on[zone] = look
end

-- A gear set still on a part of the character no worn gear is using (saved into their
-- clothes by a clothing shop) comes off
local function stripLeftovers(ped)
	if not sexOf(ped) then return end
	local used = {}
	for _, look in pairs(on) do if look.component then used[look.component] = true end end

	for component in pairs(bare) do
		if not used[component] and gearOnlyOn(ped, component) then dress(ped, bareLook(component, ped)) end
	end
end

local function showLook(zone)
	local look = lookFor(zone)
	if look then putOn(zone, look) else takeOff(zone) end
end

-- Every 2 s: the clothes changed under the gear (a clothing shop, an outfit, a respawn)
-- and it goes back on, in the size the new clothes need; what they put on comes back
-- when the gear comes off.
local function keepOn()
	local ped = cache.ped

	for zone in pairs(worn) do
		local look = lookFor(zone)

		if look and (not on[zone] or not wearing(ped, look)) then
			-- Their clothes changed only if what was put on is gone (not when the look itself
			-- changed: another size, a set loaded, the holster's pistol)
			if on[zone] and not wearing(ped, on[zone]) then restore[zone] = ownClothes(ped, look) end
			putOn(zone, look)
		end
	end

	stripLeftovers(ped)
end

---------------------------------------------------------------------------------------
-- Armour: what a carrier's plates give, worked out by the server (state gearArmour,
-- nil with no carrier). Hits are told to the server, which wears the plates down.
---------------------------------------------------------------------------------------

local armour = LocalPlayer.state.gearArmour

AddStateBagChangeHandler('gearArmour', ('player:%s'):format(cache.serverId), function(_, _, value)
	armour = value
	if armour and not isDown(cache.ped) then SetPedArmour(cache.ped, armour) end
end)

CreateThread(function()
	local lastPed, wasDown

	while true do
		Wait(250)
		local ped = cache.ped

		if armour then
			if isDown(ped) then
				wasDown = true
			elseif wasDown or ped ~= lastPed then
				wasDown = false
				SetPedArmour(ped, armour)
			else
				local now = GetPedArmour(ped)

				if now < armour then
					armour = now
					TriggerServerEvent('ox_inventory:gearArmourLost', now)
				elseif now > armour then
					SetPedArmour(ped, armour) -- armour only from the plates
				end
			end

			lastPed = ped
		elseif Config.onlyFromCarrier and PlayerData.loaded and not isDown(ped) and GetPedArmour(ped) > 0 then
			SetPedArmour(ped, 0)
		end
	end
end)

---------------------------------------------------------------------------------------
-- Masks. A respirator: gas (tear gas, BZ) doesn't hurt you or knock you over. A
-- rebreather: air under water for its seconds, refilling at the surface.
---------------------------------------------------------------------------------------

-- Weapon hashes compared unsigned (events and hash literals may differ in sign)
local function hashKey(hash)
	hash = math.tointeger(hash)
	return hash and hash & 0xFFFFFFFF
end

local GAS = { [hashKey(`WEAPON_SMOKEGRENADE`)] = true, [hashKey(`WEAPON_BZGAS`)] = true }
local health

local function masked(list)
	return worn.mask and list[worn.mask.name]
end

CreateThread(function()
	while true do
		Wait(100)
		local ped = cache.ped
		local protected = masked(respirators) and true or false
		SetPedConfigFlag(ped, 367, protected) -- CPED_CONFIG_FLAG_DontActivateRagdollFromSmokeGrenade
		health = protected and GetEntityHealth(ped) or nil
	end
end)

-- Damage from gas, with a respirator on, is given back at once
AddEventHandler('gameEventTriggered', function(name, args)
	if name ~= 'CEventNetworkEntityDamage' or not health then return end

	local ped = cache.ped
	if args[1] == ped and GAS[hashKey(args[7])] and not isDown(ped) and GetEntityHealth(ped) < health then
		SetEntityHealth(ped, health)
	end
end)

-- Under water the rebreather holds the game's own breath timer at the share of its air
-- left (the native takes a percentage of a normal breath), so a HUD's oxygen reading
-- drains with it. Out of air, the game's timer is left at 0 and you drown as usual.
-- Drowning proof doesn't stop a player drowning (tried first; Test Run 6, 14 Oct).
CreateThread(function()
	local air, warned
	local last = GetGameTimer()

	while true do
		local now = GetGameTimer()
		local elapsed = (now - last) / 1000
		last = now
		local seconds = masked(rebreathers)

		if not seconds then
			air, warned = nil, nil
			Wait(500)
		elseif IsPedSwimmingUnderWater(cache.ped) then
			local had = air or seconds
			air = math.max(0, had - elapsed)

			if air > 0 then
				-- At least 2% (0.2 s of a breath), so the game's count can't reach 0 between two
				SetPlayerUnderwaterTimeRemaining(PlayerId(), math.max(2.0, air / seconds * 100.0))
			elseif had > 0 then
				SetPlayerUnderwaterTimeRemaining(PlayerId(), 0.0)
				lib.notify({ id = 'gear_air', type = 'error', description = locale('gear_air_out') })
			end

			if air > 0 and air <= 20 and not warned then
				warned = true
				lib.notify({ id = 'gear_air', type = 'inform', description = locale('gear_air_low') })
			end

			Wait(100)
		else
			air = math.min(seconds, (air or seconds) + elapsed * 10) -- 10 s of air a second at the surface
			if air > 20 then warned = nil end
			Wait(500)
		end
	end
end)

---------------------------------------------------------------------------------------
-- What's worn, from the Wearables slots.
---------------------------------------------------------------------------------------

local function same(a, b)
	if a == b then return true end
	if not a or not b then return false end
	return a.name == b.name and a.metadata?.style == b.metadata?.style
end

local function refresh()
	local inventory = PlayerData.inventory or {}

	for i = 1, #SLOT_IDS do
		local zone = SLOT_IDS[i]
		local item = inventory[shared.playerslots + i]
		item = type(item) == 'table' and item.name and item or nil

		if not same(worn[zone], item) then
			worn[zone] = item
			showLook(zone)

			-- A carrier on or off: the bag's size over it
			if zone == 'armour' and worn.backpack then showLook('backpack') end
		end
	end

	stripLeftovers(cache.ped)

	-- A holster on: pistols are drawn and put away fast, from the hip (modules/weapon/client.lua)
	client.holsterWorn = worn.holster and holsters[worn.holster.name] and true or false
end

AddEventHandler('ox_inventory:updateInventory', function()
	refresh()
	if worn.holster then showLook('holster') end -- a pistol picked up or put away
end)

RegisterNetEvent('ox_inventory:setPlayerInventory', function()
	SetTimeout(500, refresh)
end)

AddEventHandler('ox_inventory:currentWeapon', function(weapon)
	pistolOut = weapon and weapon.hash and GetWeapontypeGroup(weapon.hash) == `GROUP_PISTOL` or false
	if worn.holster then showLook('holster') end
end)

CreateThread(function()
	while true do
		Wait(2000)
		if PlayerData.loaded then keepOn() end
	end
end)

-- A holster's styles, as buttons in its right-click menu (the server checks the pick).
for name, holster in pairs(holsters) do
	local item = Items[name]

	if item then
		item.buttons = item.buttons or {}

		for _, style in ipairs(holster.styles) do
			item.buttons[#item.buttons + 1] = {
				label = style.label,
				group = locale('gear_style'),
				action = function(slot)
					TriggerServerEvent('ox_inventory:gearHolsterStyle', slot, style.id)
				end,
			}
		end
	end
end

-- Gear taken off when the resource stops.
AddEventHandler('onResourceStop', function(resource)
	if resource ~= cache.resource then return end
	for zone in pairs(on) do takeOff(zone) end
	if armour then SetPedArmour(cache.ped, 0) end
end)

-- For a clothing shop saving the character's clothes (illenium-appearance, components as
-- { component_id, drawable, texture }): the gear on them swapped for their own clothes,
-- so gear is never saved as clothes. What they changed in the shop is kept.
exports('gearOwnClothes', function(appearance)
	local components = type(appearance) == 'table' and appearance.components
	if type(components) ~= 'table' then return appearance end

	local ped, own = cache.ped, {}

	for zone, look in pairs(on) do
		if look.component and restore[zone] and wearing(ped, look) then own[look.component] = restore[zone] end
	end

	for component in pairs(bare) do
		if not own[component] and gearOnlyOn(ped, component) then own[component] = bareLook(component, ped) end
	end

	for _, c in pairs(components) do
		local mine = type(c) == 'table' and own[c.component_id]
		if mine then c.drawable, c.texture = mine[1], mine[2] or 0 end
	end

	return appearance
end)

-- /gearcheck: what's worn, put on and kept as your own clothes, and what each gear part
-- of the character shows, printed to F8 (and the game's log).
local function describe(look)
	if not look then return '-' end
	return ('%s %d/%d'):format(look.collection or (look.prop and 'prop' or 'game'), look[1], look[2] or 0)
end

RegisterCommand('gearcheck', function()
	local ped = cache.ped

	for i = 1, #SLOT_IDS do
		local zone = SLOT_IDS[i]
		print(('[gear] %s: worn %s, on %s, own clothes %s'):format(zone, worn[zone] and worn[zone].name or '-', describe(on[zone]), describe(restore[zone])))
	end

	for _, c in ipairs({ 1, 5, 7, 8, 9 }) do
		print(('[gear] component %d: drawable %d texture %d, set %s #%d'):format(c, GetPedDrawableVariation(ped, c), GetPedTextureVariation(ped, c),
			collectionOn(ped, c) ~= '' and collectionOn(ped, c) or 'game', GetPedDrawableVariationCollectionLocalIndex(ped, c)))
	end

	lib.notify({ description = 'Gear printed to F8' })
end, false)

-- /geartry <bag|mask|vest|holster> <drawable> [texture]: a look tried on (only here, to
-- find the numbers for data/gear.lua). With no number, back as it was.
local TRY = { bag = { 5, 'backpack' }, mask = { 1, 'mask' }, vest = { 9, 'armour' }, holster = { 8, 'holster' } }

RegisterCommand('geartry', function(_, args)
	local try = TRY[args[1]]
	if not try then return lib.notify({ type = 'error', description = '/geartry bag|mask|vest|holster <drawable> [texture]' }) end

	local ped, component, zone = cache.ped, try[1], try[2]
	local drawable = tonumber(args[2])

	if not drawable then
		if on[zone] then dress(ped, on[zone]) elseif restore[zone] then dress(ped, restore[zone]) end
		return
	end

	local drawables = GetNumberOfPedDrawableVariations(ped, component)
	if drawable < 0 or drawable >= drawables then
		return lib.notify({ type = 'error', description = ('%s: 0 to %d on this character'):format(args[1], drawables - 1) })
	end

	local textures = GetNumberOfPedTextureVariations(ped, component, drawable)
	local texture = math.max(0, math.min(tonumber(args[3]) or 0, textures - 1))
	SetPedComponentVariation(ped, component, drawable, texture, 0)
	lib.notify({ description = ('%s %d, texture %d (%d textures, %d in all)'):format(args[1], drawable, texture, textures, drawables) })
end, false)
