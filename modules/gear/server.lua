if not lib then return end

-- Gear worn in the Wearables slots (data/gear.lua): bags (containers, and carrying more
-- while worn), plate carriers (containers of armour plates; the plates are the
-- player's armour and wear down with hits), holster styles, and keeping the
-- Wearables slots tidy when a player loads.

local Inventory = require 'modules.inventory.server'
local Items = require 'modules.items.server'
local SLOT_IDS = require 'modules.wearables.shared'
local Config = lib.load('data.gear') or {}

local bags = Config.bags or {}
local carriers = Config.carriers or {}
local plates = Config.plates or {}
local holsters = Config.holsters or {}

local Gear = {}

---The slot a Wearables zone is in, for a player inventory.
---@param inv OxInventory
---@param zone string
local function slotOf(inv, zone)
	for i = 1, #SLOT_IDS do
		if SLOT_IDS[i] == zone then return (inv.bagSlots or shared.playerslots) + i end
	end
end

---The item worn in a zone, if any.
local function worn(inv, zone)
	local slot = slotOf(inv, zone)
	return slot and inv.items[slot] or nil
end

local function setOf(list)
	local set = {}
	for i = 1, #list do set[list[i]] = true end
	return set
end

---The plates a carrier takes and what each gives in it: its own `values`, else every
---plate at its value in `plates`.
---@param name string the carrier item
local function valuesOf(name)
	local carrier = carriers[name]
	return carrier and carrier.values or plates
end

-- Bags and plate carriers are containers (as modules/items/containers.lua makes them).
CreateThread(function()
	while not shared.ready do Wait(50) end

	for name, bag in pairs(bags) do
		if Items(name) then
			Items.containers[name] = { size = { bag.slots, bag.weight } }
		else
			warn(('gear: bag "%s" is not an item'):format(name))
		end
	end

	for name, carrier in pairs(carriers) do
		-- Only its own plates go in, and room for the heaviest of them in every pocket
		local plateNames, plateWeight = {}, 0

		for plate in pairs(valuesOf(name)) do
			local item = Items(plate)
			if item then
				plateNames[#plateNames + 1] = plate
				plateWeight = math.max(plateWeight, item.weight or 0)
			else
				warn(('gear: plate "%s" (carrier "%s") is not an item'):format(plate, name))
			end
		end

		if Items(name) then
			Items.containers[name] = {
				size = { carrier.plates or 3, math.max(1, (carrier.plates or 3) * plateWeight) },
				whitelist = setOf(plateNames),
			}
		else
			warn(('gear: carrier "%s" is not an item'):format(name))
		end
	end
end)

---A container's own inventory (its contents), loaded if it isn't yet.
---@param item SlotWithItem
---@return OxInventory?
local function contentsOf(item)
	local id = item.metadata?.container
	if not id then return end

	local inv = Inventory(id)
	if inv then return inv end

	local size = item.metadata.size or (Items.containers[item.name] and Items.containers[item.name].size)
	if not size then return end

	return Inventory.Create(id, item.label, 'container', size[1], 0, size[2], false)
end

---What the plates in a carrier give: each plate's points in it, less the wear it has taken.
---@param contents OxInventory?
---@param values table<string, number> the carrier's plate values (valuesOf)
---@return number
local function armourOf(contents, values)
	if not contents then return 0 end

	local total = 0

	for _, plate in pairs(contents.items) do
		local points = values[plate.name]
		if points then
			total += points * math.max(0, math.min(100, tonumber(plate.metadata?.durability) or 100)) / 100
		end
	end

	return math.min(100, math.floor(total + 0.5))
end

---Weight limit and armour from what's worn, sent where they're needed.
---@param inv OxInventory
function Gear.apply(inv)
	inv = Inventory(inv) --[[@as OxInventory]]
	if not inv or not inv.player then return end

	local bag = worn(inv, 'backpack')
	local maxWeight = shared.playerweight + (bag and bags[bag.name] and bags[bag.name].weight or 0)
	if inv.maxWeight ~= maxWeight then Inventory.SetMaxWeight(inv, maxWeight) end

	local carrier = worn(inv, 'armour')
	local armour = carrier and carriers[carrier.name] and armourOf(contentsOf(carrier), valuesOf(carrier.name)) or nil
	local state = Player(inv.id).state

	if state.gearArmour ~= armour then state:set('gearArmour', armour, true) end
end

---Anything in a Wearables slot that doesn't go there, or in a slot past the last one (a
---layout that had more), moves to a free pocket; a container made before it was
---registered as one gets its id. For a player's items as they load.
---@param inv OxInventory
function Gear.sortLoaded(inv)
	local first = inv.bagSlots or shared.playerslots
	local last = first + #SLOT_IDS
	local loose = {}

	for slot, item in pairs(inv.items) do
		local zone = slot > first and SLOT_IDS[slot - first]
		local data = Items(item.name)

		if slot > first and (not zone or not data or data.wearable ~= zone) then
			loose[#loose + 1] = slot
		end

		local container = Items.containers[item.name]
		if container and not item.metadata.container then
			item.metadata.container = ('%s%s'):format(string.char(math.random(65, 90), math.random(65, 90), math.random(65, 90)), os.time() + slot)
			item.metadata.size = container.size
			inv.changed = true
		end
	end

	table.sort(loose)

	for i = 1, #loose do
		local from = loose[i]
		local to

		for slot = 1, first do
			if not inv.items[slot] then to = slot break end
		end

		-- No room: it stays where it is till there is
		if not to then
			lib.print.warn(('gear: no free pocket for %s in slot %d of %s'):format(inv.items[from].name, from, inv.label))
			break
		end

		local item = inv.items[from]
		inv.items[from] = nil
		item.slot = to
		inv.items[to] = item
		inv.changed = true
	end

	if #loose > 0 then
		lib.print.info(('gear: moved %d item(s) out of the Wearables slots for %s (up to slot %d)'):format(#loose, inv.label, last))
	end
end

-- Hits: the player's game says the armour went down to `left`. The plates wear down to
-- match, the outermost (last) first; a plate at 0 breaks. Reports in one moment are
-- taken together, the lowest counting; nothing a game says ever mends a plate.
local reported = {}

local function wearPlates(src)
	local left = reported[src]
	reported[src] = nil

	local inv = Inventory(src)
	local carrier = inv and worn(inv, 'armour')
	local contents = carrier and carriers[carrier.name] and contentsOf(carrier)
	if not contents then return end

	local values = valuesOf(carrier.name)
	local damage = armourOf(contents, values) - math.max(0, left)
	if damage <= 0 then return end

	for slot = contents.slots, 1, -1 do
		local plate = contents.items[slot]
		local points = plate and values[plate.name]

		if points and damage > 0 then
			local durability = math.max(0, math.min(100, tonumber(plate.metadata.durability) or 100))
			local has = points * durability / 100
			local take = math.min(has, damage)
			damage -= take

			local remaining = math.floor((has - take) / points * 100 + 0.5)

			if remaining <= 0 then
				Inventory.RemoveItem(contents, plate.name, 1, nil, slot)
			else
				local metadata = table.clone(plate.metadata)
				metadata.durability = remaining
				metadata.label = ('%s (%d%%)'):format(Items(plate.name).label, remaining)
				Inventory.SetMetadata(contents, slot, metadata)
			end
		end
	end

	Gear.apply(inv)
end

RegisterNetEvent('ox_inventory:gearArmourLost', function(left)
	local src = source
	left = tonumber(left)
	if not left then return end

	if reported[src] then
		reported[src] = math.min(reported[src], left)
		return
	end

	reported[src] = left

	SetTimeout(150, function()
		if GetPlayerName(src) then wearPlates(src) else reported[src] = nil end
	end)
end)

AddEventHandler('playerDropped', function()
	reported[source] = nil
end)

-- A holster's style, picked from its right-click menu.
RegisterNetEvent('ox_inventory:gearHolsterStyle', function(slot, style)
	local inv = Inventory(source)
	local item = inv and type(slot) == 'number' and inv.items[slot]
	local holster = item and holsters[item.name]
	if not holster or type(style) ~= 'string' then return end

	for i = 1, #holster.styles do
		if holster.styles[i].id == style then
			local metadata = table.clone(item.metadata)
			metadata.style = style
			metadata.label = ('%s (%s)'):format(Items(item.name).label, holster.styles[i].label)
			return Inventory.SetMetadata(inv, slot, metadata)
		end
	end
end)

-- Bags on the ground. A worn bag that falls off a player (dropWornBag) lies there as
-- itself: a prop each game draws (modules/groundbag/client.lua) with a target to open it
-- or pick it up, kneeling for `ground.pickup` seconds (data/gear.lua). Its things stay
-- in its container all along. Kept in memory, like drops: a restart loses the bags on
-- the ground (their things stay saved under each bag's container id).
local ground = Config.ground or {}
local REACH = ground.reach or 2.0
local PICKUP = math.floor((ground.pickup or 3) * 1000)

local groundBags = {} -- [id] = { id, item, label, coords, instance, model }
local picking = {}    -- [src] = { id, at }: a pickup started, for its timer

---What every game is told: the bags on the ground (numbers only, for the state bag).
local function publishGround()
	local list = {}

	for id, bag in pairs(groundBags) do
		list[#list + 1] = {
			id = id, label = bag.label, model = bag.model, instance = bag.instance,
			x = bag.coords.x, y = bag.coords.y, z = bag.coords.z,
		}
	end

	GlobalState.oxGroundBags = list
end

---A ground bag's container (its things), loaded if it isn't.
local function containerOf(bag)
	local metadata = bag.item.metadata
	if not metadata.container then return end

	local container = Inventory(metadata.container)

	if not container and metadata.size then
		container = Inventory.Create(metadata.container, bag.label, 'container', metadata.size[1], 0, metadata.size[2], false)
	end

	return container
end

---The player is by it: the same instance, and within reach (a ped's position is its
---middle, about a metre above its feet; the bag lies on the ground).
local function byBag(src, bag)
	if Player(src).state.instance ~= bag.instance then return false end

	local ped = GetPlayerPed(src)
	if not ped or ped == 0 then return false end

	local at = GetEntityCoords(ped)
	local dx, dy, dz = at.x - bag.coords.x, at.y - bag.coords.y, at.z - bag.coords.z

	return math.sqrt(dx * dx + dy * dy + dz * dz) <= REACH + 1.0
end

---A worn bag falls to the ground behind the player, with everything in it (a bag's
---things are kept under its container id, so they go wherever it goes), and the weight
---limit comes back down. For scripts that knock a player down or kill them. A job kit's
---bag stays on them, and swapItems hooks aren't run. Returns the ground bag's id, or nil.
---@param playerId number
---@param coords? vector3 where it lands (on the ground just behind them when nil)
---@return string?
function Gear.dropWornBag(playerId, coords)
	local inv = Inventory(playerId)
	if not inv or not inv.player then return end

	local slot = slotOf(inv, 'backpack')
	local bag = slot and inv.items[slot]
	if not bag or bag.metadata?.loadout then return end

	if not coords then
		local ped = GetPlayerPed(playerId)
		if not ped or ped == 0 then return end
		local at, heading = GetEntityCoords(ped), math.rad(GetEntityHeading(ped))
		-- off their back: 0.6 m behind, at their feet
		coords = vec3(at.x + math.sin(heading) * 0.6, at.y - math.cos(heading) * 0.6, at.z - 0.9)
	end

	-- Its own bag can't stay open on the right once it's gone.
	if inv.containerSlot == slot then inv:closeInventory() end

	local id
	repeat id = ('bag-%s'):format(math.random(100000, 999999)) until not groundBags[id]

	local item = table.clone(bag)
	item.metadata = table.clone(bag.metadata)
	local model = bags[bag.name] and bags[bag.name].drop

	groundBags[id] = {
		id = id,
		item = item,
		label = item.metadata.label or (Items(bag.name) or bag).label,
		coords = coords,
		instance = Player(playerId).state.instance,
		model = model and GetHashKey(model) or nil,
	}

	inv.items[slot] = nil
	inv.weight -= bag.weight
	inv.changed = true

	inv:syncSlotsWithClients({ { item = { slot = slot }, inventory = inv.id } }, true)
	if server.syncInventory then server.syncInventory(inv) end
	Gear.apply(inv)
	publishGround()

	return id
end

exports('dropWornBag', Gear.dropWornBag)

---The things in a bag on the ground, for opening it (server.lua's openInventory, the
---target's "Open"). Nil when it's gone, or the player isn't by it. It closes like a stash
---when they walk off.
---@param src number
---@param id string
function Gear.groundContainer(src, id)
	local bag = groundBags[id]
	if not bag or not byBag(src, bag) then return end

	local container = containerOf(bag)
	if not container then return end

	container.coords = vec3(bag.coords.x, bag.coords.y, bag.coords.z)
	container.distance = REACH + 1.0

	return container
end

-- Picking one up: the timer is the server's too, so a game can't skip it.
lib.callback.register('ox_inventory:groundBagPickupStart', function(src, id)
	local bag = groundBags[id]
	if not bag or not byBag(src, bag) then return false end

	picking[src] = { id = id, at = GetGameTimer() }

	return PICKUP
end)

lib.callback.register('ox_inventory:groundBagPickup', function(src, id)
	local started = picking[src]
	picking[src] = nil

	local bag = groundBags[id]
	if not bag then return false, 'ground_bag_gone' end
	if not started or started.id ~= id or GetGameTimer() - started.at < PICKUP * 0.9 then return false end
	if not byBag(src, bag) then return false, 'ground_bag_far' end

	local inv = Inventory(src)
	local item = Items(bag.item.name)
	if not inv or not inv.player or not item then return false end

	-- What's in it now goes into its weight (moves on the ground don't update it).
	local container = containerOf(bag)
	local metadata = table.clone(bag.item.metadata)
	if container then metadata.weight = container.weight end

	-- On their back if the backpack slot's free (as buying one does), else a pocket.
	local wornSlot = slotOf(inv, 'backpack')
	local wear = wornSlot and not inv.items[wornSlot] and item.wearable == 'backpack'
	local slot = wear and wornSlot or Inventory.GetEmptySlot(inv)
	if not slot then return false, 'ground_bag_no_room' end

	local weight = Inventory.SlotWeight(item, { count = 1, metadata = metadata })
	local limit = inv.maxWeight + (wear and bags[item.name] and bags[item.name].weight or 0)
	if inv.weight + weight > limit then return false, 'ground_bag_heavy' end

	groundBags[id] = nil
	publishGround()

	if container then
		Inventory.CloseAll(container)
		container.coords, container.distance = nil, nil
	end

	Inventory.SetSlot(inv, item, 1, metadata, slot)
	inv:syncSlotsWithClients({ { item = inv.items[slot], inventory = inv.id } }, true)
	if server.syncInventory then server.syncInventory(inv) end
	Gear.apply(inv)
	require('modules.wearables.server').syncEquipped(inv)

	return true
end)

AddEventHandler('playerDropped', function()
	picking[source] = nil
end)

return Gear
