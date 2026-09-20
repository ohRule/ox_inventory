if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items = require 'modules.items.server'
local Config = lib.load('data.lootprops') or {}

---@param location table
local function categoryOf(location)
	return Config.categories and Config.categories[location.category]
end

---@param id string
local function locationById(id)
	for i = 1, #(Config.locations or {}) do
		local location = Config.locations[i]
		if location.id == id then return location end
	end
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

---@param inv OxInventory
local function clearItems(inv)
	for slot = 1, inv.slots do
		inv.items[slot] = nil
	end
	inv.weight = 0
end

---Roll a category pool into the crate. Each entry is an independent % chance.
---@param inv OxInventory
---@param category table
local function generate(inv, category)
	clearItems(inv)
	inv.searched = {}
	inv.revealing = {}
	inv.generatedAt = os.time()
	inv.pendingReset = false

	if math.random(100) <= (category.emptyChance or 0) then
		return
	end

	local rolled = {}

	for i = 1, #(category.items or {}) do
		local entry = category.items[i]
		if Items(entry.name) and math.random(100) <= (entry.chance or 100) then
			local min = entry.min or entry.count or 1
			local max = entry.max or min
			rolled[#rolled + 1] = {
				name = entry.name,
				count = math.random(min, max),
			}
		end
	end

	-- Guarantee a floor when the independent rolls came up short
	if category.minItems and #rolled < category.minItems then
		local extras = {}
		for i = 1, #(category.items or {}) do
			local entry = category.items[i]
			if Items(entry.name) then extras[#extras + 1] = entry end
		end
		shuffle(extras)
		for i = 1, #extras do
			if #rolled >= category.minItems then break end
			local entry = extras[i]
			local already = false
			for j = 1, #rolled do
				if rolled[j].name == entry.name then already = true break end
			end
			if not already then
				local min = entry.min or 1
				local max = entry.max or min
				rolled[#rolled + 1] = { name = entry.name, count = math.random(min, max) }
			end
		end
	end

	local maxItems = math.min(category.maxItems or Config.maxItems or 5, Config.maxItems or 5, inv.slots)

	if #rolled > maxItems then
		shuffle(rolled)
		for i = #rolled, maxItems + 1, -1 do
			rolled[i] = nil
		end
	end

	-- Pack into consecutive slots so the search reveal has no empty gaps
	for i = 1, #rolled do
		if i > inv.slots then break end
		Inventory.AddItem(inv, rolled[i].name, rolled[i].count, nil, i)
	end
end

---@param inv OxInventory
---@param location table
local function shouldReset(inv, location)
	if not inv.generatedAt then return true end
	local resetTime = location.resetTime or Config.resetTime or 600
	return (os.time() - inv.generatedAt) >= resetTime
end

---@param id string
---@return OxInventory?
local function ensure(id)
	local location = locationById(id)
	if not location then return end

	local category = categoryOf(location)
	if not category then return end

	local inv = Inventory(id)
	if not inv then
		local coords = location.coords
		inv = Inventory.Create(id, category.label or locale('loot_container'), 'lootprop', category.slots or Config.slots or 5, 0, 100000, false, {})
		if not inv then return end
		inv.coords = vec3(coords.x, coords.y, coords.z)
		inv.distance = location.distance or 2.2
		inv.searched = {}
		inv.revealing = {}
	end

	if shouldReset(inv, location) then
		if next(inv.openedBy) then
			inv.pendingReset = true
		else
			generate(inv, category)
		end
	elseif not inv.generatedAt then
		generate(inv, category)
	end

	return inv
end

---@param inv OxInventory
---@param source number
local function visibleItems(inv, source)
	local searched = inv.searched and inv.searched[source] or {}
	local items = {}

	for slot, item in pairs(inv.items) do
		if searched[slot] then
			items[slot] = item
		end
	end

	return items
end

---@param inv OxInventory
---@param source number
---@param slot number
local function hasSearched(inv, source, slot)
	return inv.searched and inv.searched[source] and inv.searched[source][slot]
end

---Walk slots left-to-right and reveal items one at a time for this player.
---@param source number
---@param inv OxInventory
local function startSearch(source, inv)
	if inv.revealing[source] then return end
	inv.revealing[source] = true

	CreateThread(function()
		local delay = Config.searchDelay or 550

		for slot = 1, inv.slots do
			local playerInv = Inventory(source)
			if not playerInv or playerInv.open ~= inv.id then break end

			inv.searched[source] = inv.searched[source] or {}

			if not inv.searched[source][slot] and inv.items[slot] then
				TriggerClientEvent('ox_inventory:lootSearch', source, { slot = slot, inventory = inv.id })
				Wait(delay)

				playerInv = Inventory(source)
				if not playerInv or playerInv.open ~= inv.id then break end

				inv.searched[source][slot] = true
				playerInv:syncSlotsWithPlayer({
					{ item = inv.items[slot] or { slot = slot }, inventory = inv.id }
				}, playerInv.weight)
			else
				inv.searched[source][slot] = true
			end
		end

		TriggerClientEvent('ox_inventory:lootSearchDone', source, { inventory = inv.id })
		inv.revealing[source] = nil
	end)
end

---Take-only until a slot has been searched by this player.
local function allowMove(fromInventory, toInventory, fromSlot, toSlot, source)
	if toInventory.type == 'lootprop' and fromInventory.id ~= toInventory.id then
		return false
	end

	if fromInventory.type == 'lootprop' and not hasSearched(fromInventory, source, fromSlot) then
		return false
	end

	if toInventory.type == 'lootprop' and not hasSearched(toInventory, source, toSlot) then
		return false
	end

	return true
end

AddEventHandler('ox_inventory:openedInventory', function(playerId, invId)
	local inv = invId and Inventory(invId)
	if inv and inv.type == 'lootprop' then
		startSearch(playerId, inv)
	end
end)

AddEventHandler('ox_inventory:closedInventory', function(playerId, invId)
	local inv = invId and Inventory(invId)
	if not inv or inv.type ~= 'lootprop' then return end

	inv.revealing[playerId] = nil

	if inv.pendingReset and not next(inv.openedBy) then
		local location = locationById(inv.id)
		local category = location and categoryOf(location)
		if category then generate(inv, category) end
	end
end)

CreateThread(function()
	while not shared.ready do Wait(50) end
	for i = 1, #(Config.locations or {}) do
		ensure(Config.locations[i].id)
	end
end)

return {
	ensure = ensure,
	visibleItems = visibleItems,
	allowMove = allowMove,
	locations = Config.locations or {},
}
