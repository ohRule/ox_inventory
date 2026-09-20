if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items = require 'modules.items.server'
local db = require 'modules.mysql.server'
local Loadout = require 'modules.loadout.shared'
local Config, Kits, vehicleAllowed = Loadout.Config, Loadout.Kits, Loadout.vehicleAllowed

local KitById = {}

for i = 1, #Kits do
	local kit = Kits[i]
	if kit.id then
		KitById[kit.id] = kit
	end
end

---@param inv OxInventory
---@param entity number
---@return boolean
local function canAccessVehicle(inv, entity)
	local function hasGroup(groups)
		return server.hasGroup(inv, groups)
	end

	if Loadout.getArmoury(entity, hasGroup) then return true end

	for i = 1, #Kits do
		local kit = Kits[i]
		if kit.groups and hasGroup(kit.groups) and vehicleAllowed(kit, entity) then
			return true
		end
	end

	return false
end

---@param netId number
---@return number?
local function getVehicle(netId)
	if type(netId) ~= 'number' then return end

	local entity = NetworkGetEntityFromNetworkId(netId)
	if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end

	return entity
end

---@param source number
---@param entity number
---@return boolean
local function isNearVehicle(source, entity)
	local ped = GetPlayerPed(source)
	if ped == 0 then return false end

	local distance = (Config.distance or 2.5) + 2.0
	return #(GetEntityCoords(ped) - GetEntityCoords(entity)) <= distance
end

---@param inv OxInventory
---@return string?
local function getActiveLoadout(inv)
	for _, item in pairs(inv.items) do
		local loadout = item.metadata and item.metadata.loadout
		if loadout then return loadout end
	end
end

---Remove every item tagged as part of a job loadout.
---@param inv OxInventory
---@param silent boolean?
---@return boolean
local function stripLoadout(inv, silent)
	local slots = {}

	for slot, item in pairs(inv.items) do
		if item.metadata and item.metadata.loadout then
			slots[#slots + 1] = { slot = slot, name = item.name, count = item.count }
		end
	end

	if #slots == 0 then return false end

	TriggerClientEvent('ox_inventory:disarm', inv.id, true)

	for i = 1, #slots do
		local entry = slots[i]
		Inventory.RemoveItem(inv, entry.name, entry.count, nil, entry.slot)
	end

	if not silent then
		TriggerClientEvent('ox_lib:notify', inv.id, {
			type = 'inform',
			description = locale('loadout_returned'),
		})
	end

	return true
end

---@param inv OxInventory
---@param kit table
---@return boolean, string?
local function canCarryKit(inv, kit)
	local extraWeight = 0
	local extraSlots = 0

	for i = 1, #kit.items do
		local entry = kit.items[i]
		local item = Items(entry.name)
		if not item then return false, 'invalid_item' end

		local count = entry.count or 1
		extraWeight += item.weight * count
		extraSlots += item.stack and 1 or count
	end

	if inv.weight + extraWeight > inv.maxWeight then
		return false, 'cannot_carry'
	end

	local empty = 0
	for i = 1, inv.slots do
		if not inv.items[i] then empty += 1 end
	end

	if empty < extraSlots then
		return false, 'cannot_carry'
	end

	return true
end

---@param inv OxInventory
---@param kit table
---@return boolean, string?
local function giveKit(inv, kit)
	-- Return the current kit first so taking another one restocks/replaces
	stripLoadout(inv, true)

	local ok, err = canCarryKit(inv, kit)
	if not ok then return false, err end

	for i = 1, #kit.items do
		local entry = kit.items[i]
		local metadata = entry.metadata and table.clone(entry.metadata) or {}
		metadata.loadout = kit.id

		local success = Inventory.AddItem(inv, entry.name, entry.count or 1, metadata)
		if not success then
			stripLoadout(inv, true)
			return false, 'cannot_carry'
		end
	end

	return true
end

lib.callback.register('ox_inventory:getLoadouts', function(source, netId)
	local inv = Inventory(source)
	if not inv?.player then return { kits = {}, active = false } end

	local entity = getVehicle(netId)
	if not entity or not isNearVehicle(source, entity) then
		return { kits = {}, active = false }
	end

	local kits = {}

	for i = 1, #Kits do
		local kit = Kits[i]
		if kit.groups and server.hasGroup(inv, kit.groups) and vehicleAllowed(kit, entity) then
			kits[#kits + 1] = {
				id = kit.id,
				label = kit.label,
				description = kit.description,
				icon = kit.icon,
			}
		end
	end

	return { kits = kits, active = getActiveLoadout(inv) and true or false }
end)

RegisterNetEvent('ox_inventory:giveLoadout', function(kitId, netId)
	local source = source
	local inv = Inventory(source)
	if not inv?.player then return end

	local kit = KitById[kitId]
	if not kit or not kit.groups or not server.hasGroup(inv, kit.groups) then return end

	local entity = getVehicle(netId)
	if not entity or not isNearVehicle(source, entity) then return end
	if not vehicleAllowed(kit, entity) then return end

	local success, err = giveKit(inv, kit)
	if not success then
		return TriggerClientEvent('ox_lib:notify', source, {
			type = 'error',
			description = locale(err == 'cannot_carry' and 'loadout_cannot_carry' or 'loadout_unavailable'),
		})
	end

	TriggerClientEvent('ox_lib:notify', source, {
		type = 'success',
		description = locale('loadout_given', kit.label),
	})
end)

RegisterNetEvent('ox_inventory:returnLoadout', function(netId)
	local source = source
	local inv = Inventory(source)
	if not inv?.player then return end

	local entity = getVehicle(netId)
	if not entity or not isNearVehicle(source, entity) or not canAccessVehicle(inv, entity) then return end

	if not stripLoadout(inv) then
		TriggerClientEvent('ox_lib:notify', source, {
			type = 'error',
			description = locale('loadout_none'),
		})
	end
end)

-- Strip kit items before a player inventory is saved/unloaded so they never persist
local removeInventory = Inventory.Remove

function Inventory.Remove(inv)
	inv = Inventory(inv)
	if inv?.player then
		stripLoadout(inv, true)
	end

	return removeInventory(inv)
end

---@param playerInv OxInventory
---@param armoury table
---@return table, table<string, true>, number
local function seedArmoury(playerInv, armoury)
	local items, allowed, slot = {}, {}, 0

	for i = 1, #armoury.items do
		local entry = armoury.items[i]
		local item = Items(entry.name)
		if item then
			allowed[item.name] = true
			local remaining = entry.count or 1

			while remaining > 0 do
				local metadata, count = Items.Metadata(playerInv, item, entry.metadata and table.clone(entry.metadata) or {}, remaining)
				slot += 1
				local data = {
					name = item.name,
					label = item.label,
					count = count,
					metadata = metadata,
					slot = slot,
					stack = item.stack,
					close = item.close,
					description = item.description,
				}
				data.weight = Inventory.SlotWeight(item, data)
				items[slot] = data
				remaining -= count
			end
		end
	end

	return items, allowed, slot
end

---@param armoury table
---@return table<string, true>
local function allowedItems(armoury)
	local allowed = {}
	for i = 1, #armoury.items do
		local name = armoury.items[i].name
		if name then allowed[name] = true end
	end
	return allowed
end

---Create or load this vehicle's armoury. Stock is keyed by plate, not model.
---@param source number
---@param netId number
---@return OxInventory?
local function ensureArmoury(source, netId)
	local playerInv = Inventory(source)
	if not playerInv?.player then return end

	local entity = getVehicle(netId)
	if not entity or not isNearVehicle(source, entity) then return end

	local armoury = Loadout.getArmoury(entity, function(groups)
		return server.hasGroup(playerInv, groups)
	end)
	if not armoury then return end

	local plate = Loadout.vehiclePlate(entity)
	if plate == '' then return end

	local id = ('armoury:%s:%s'):format(armoury.id, plate)
	local inv = Inventory(id)
	if inv then
		inv.armouryItems = inv.armouryItems or allowedItems(armoury)
		inv.coords = GetEntityCoords(entity)
		inv.distance = Config.distance or 2.5
		return inv
	end

	local saved = db.loadStash('', id)
	local items, allowed, usedSlots

	if saved then
		items = select(1, Inventory.Load(id, 'armoury', ''))
		allowed = allowedItems(armoury)
		usedSlots = 0
	else
		items, allowed, usedSlots = seedArmoury(playerInv, armoury)
	end

	inv = Inventory.Create(id, armoury.label or locale('vehicle_armoury'), 'armoury', math.max(armoury.slots or 0, usedSlots), 0, armoury.maxWeight or 100000, false, items, armoury.groups)
	if not inv then return end

	inv.armouryItems = allowed
	inv.coords = GetEntityCoords(entity)
	inv.distance = Config.distance or 2.5
	inv.changed = not saved

	return inv
end

---@param fromInventory OxInventory
---@param toInventory OxInventory
---@param fromSlot number
---@return boolean
local function allowMove(fromInventory, toInventory, fromSlot)
	if fromInventory == toInventory then return true end

	local armoury = fromInventory.type == 'armoury' and fromInventory or toInventory.type == 'armoury' and toInventory
	if not armoury then return true end

	local other = armoury == fromInventory and toInventory or fromInventory
	return other.type == 'player'
end

return {
	ensure = ensureArmoury,
	allowMove = allowMove,
}
