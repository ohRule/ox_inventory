if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items = require 'modules.items.server'
local Config = lib.load('data.furnaces') or {}

local ORE_SLOTS = 6
local FUEL_SLOTS = 3
local OUTPUT_SLOTS = 6
local TOTAL_SLOTS = ORE_SLOTS + FUEL_SLOTS + OUTPUT_SLOTS
local DEFAULT_DURATION = 6000

local Recipes = {}
local Fuel = {}

local function buildRecipes()
	table.wipe(Recipes)
	table.wipe(Fuel)

	for name, ok in pairs(Config.fuel or {}) do
		if ok then Fuel[name] = true end
	end

	for name, recipe in pairs(Config.recipes or {}) do
		Recipes[name] = {
			duration = recipe.duration or DEFAULT_DURATION,
			consume = recipe.consume or 1,
			fuel = recipe.fuel or 1,
			output = recipe.output or {},
		}
	end
end

local function locationById(id)
	for i = 1, #(Config.locations or {}) do
		local location = Config.locations[i]
		if location.id == id then return location end
	end
end

local function acceptMap(source)
	local list = {}
	for name in pairs(source) do list[name] = true end
	return list
end

-- Slots 1-ore = ore, next fuelSlots = fuel, rest = output.
local function slotKind(inv, slot)
	local ore = inv and inv.oreSlots or ORE_SLOTS
	local fuel = inv and inv.fuelSlots or FUEL_SLOTS
	if slot <= ore then return 'ore' end
	if slot <= ore + fuel then return 'fuel' end
	return 'output'
end

local function itemKind(name)
	if Fuel[name] then return 'fuel' end
	if Recipes[name] then return 'ore' end
end

local function slotAccepts(inv, slot, name)
	return name and slotKind(inv, slot) == itemKind(name)
end

---@param inv OxInventory
local function snapshotProcess(inv)
	if not inv.process then return nil end

	local remaining = inv.process.duration
	if inv.process.started then
		remaining = math.max(0, inv.process.duration - (GetGameTimer() - inv.process.started))
	end

	return {
		id = inv.process.id,
		slot = inv.process.slot,
		name = inv.process.name,
		label = inv.process.label,
		duration = inv.process.duration,
		remaining = (inv.process.blocked or inv.process.needFuel) and 0 or remaining,
		blocked = inv.process.blocked or false,
		needFuel = inv.process.needFuel or false,
	}
end

local function syncViewers(inv)
	local payload = {
		running = inv.running and true or false,
		process = snapshotProcess(inv),
	}

	for playerId in pairs(inv.openedBy) do
		TriggerClientEvent('ox_inventory:furnaceState', playerId, payload)
	end
end

local function clearProcess(inv)
	inv.processingSlot = nil
	inv.process = nil
end

local function beginProcess(inv, slot, item, recipe)
	inv.processingSlot = slot
	inv.process = {
		id = GetGameTimer(),
		slot = slot,
		name = item.name,
		label = item.label,
		duration = recipe.duration,
		started = GetGameTimer(),
		blocked = false,
		needFuel = false,
	}
	syncViewers(inv)
end

local function outputStart(inv)
	return (inv.oreSlots or ORE_SLOTS) + (inv.fuelSlots or FUEL_SLOTS) + 1
end

local function addToOutput(inv, name, count)
	local item = Items(name)
	if not item then return false end

	local first = outputStart(inv)

	if item.stack then
		for slot = first, inv.slots do
			local slotData = inv.items[slot]
			if slotData and slotData.name == name then
				local success = Inventory.AddItem(inv, name, count, nil, slot)
				return success and true or false
			end
		end
	end

	for slot = first, inv.slots do
		if not inv.items[slot] then
			local success = Inventory.AddItem(inv, name, count, nil, slot)
			return success and true or false
		end
	end

	return false
end

local function canFitOutputs(inv, outputs)
	local occupied = {}
	local first = outputStart(inv)

	for slot = first, inv.slots do
		local slotData = inv.items[slot]
		occupied[slot] = slotData and { name = slotData.name } or false
	end

	for name in pairs(outputs) do
		local item = Items(name)
		if not item then return false end

		local placed = false

		if item.stack then
			for slot = first, inv.slots do
				if occupied[slot] and occupied[slot].name == name then
					placed = true
					break
				end
			end
		end

		if not placed then
			for slot = first, inv.slots do
				if not occupied[slot] then
					occupied[slot] = { name = name }
					placed = true
					break
				end
			end
		end

		if not placed then return false end
	end

	return true
end

local function findFuelSlot(inv, amount)
	amount = amount or 1
	local ore = inv.oreSlots or ORE_SLOTS
	local last = ore + (inv.fuelSlots or FUEL_SLOTS)
	for slot = ore + 1, last do
		local item = inv.items[slot]
		if item and Fuel[item.name] and (item.count or 0) >= amount then
			return slot, item
		end
	end
end

local function nextInput(inv)
	for slot = 1, inv.oreSlots or ORE_SLOTS do
		local item = inv.items[slot]
		if item and not (item.metadata and item.metadata.container) then
			local recipe = Recipes[item.name]
			if recipe and (item.count or 0) >= recipe.consume then
				return slot, item, recipe
			end
		end
	end
end

local function tickFurnace(inv)
	if not inv.running then return end

	if not inv.processingSlot then
		local slot, item, recipe = nextInput(inv)
		if not slot then return end
		beginProcess(inv, slot, item, recipe)
		return
	end

	local process = inv.process
	local slot = inv.processingSlot
	local item = inv.items[slot]

	if not item or not process or item.name ~= process.name then
		clearProcess(inv)
		syncViewers(inv)
		return
	end

	local recipe = Recipes[item.name]
	if not recipe then
		clearProcess(inv)
		syncViewers(inv)
		return
	end

	local fuelNeed = recipe.fuel or 0
	if fuelNeed > 0 and not findFuelSlot(inv, fuelNeed) then
		if not process.needFuel then
			process.needFuel = true
			process.blocked = true
			syncViewers(inv)
		end
		return
	end

	-- Fuel was added after a wait — restart the cook timer.
	if process.needFuel then
		process.needFuel = false
		process.blocked = false
		process.started = GetGameTimer()
		syncViewers(inv)
		return
	end

	if not process.blocked then
		local elapsed = GetGameTimer() - process.started
		if elapsed < process.duration then return end
	end

	if not canFitOutputs(inv, recipe.output) then
		if not process.blocked then
			process.blocked = true
			syncViewers(inv)
		end
		return
	end

	local take = math.min(item.count, recipe.consume)
	if take < recipe.consume then
		clearProcess(inv)
		syncViewers(inv)
		return
	end

	local fuelSlot, fuelItem = findFuelSlot(inv, fuelNeed)
	if fuelNeed > 0 and (not fuelSlot or not fuelItem) then
		process.needFuel = true
		process.blocked = true
		syncViewers(inv)
		return
	end

	if not Inventory.RemoveItem(inv, item.name, take, nil, slot) then
		clearProcess(inv)
		syncViewers(inv)
		return
	end

	if fuelNeed > 0 and fuelSlot then
		Inventory.RemoveItem(inv, fuelItem.name, fuelNeed, nil, fuelSlot)
	end

	for name, count in pairs(recipe.output) do
		addToOutput(inv, name, count)
	end

	clearProcess(inv)

	local nextSlot, nextItem, nextRecipe = nextInput(inv)
	if nextSlot then
		beginProcess(inv, nextSlot, nextItem, nextRecipe)
	else
		syncViewers(inv)
	end
end

local function applyMeta(inv)
	if inv.slots ~= TOTAL_SLOTS then
		Inventory.SetSlotCount(inv, TOTAL_SLOTS)
	end
	inv.oreSlots = ORE_SLOTS
	inv.fuelSlots = FUEL_SLOTS
	inv.inputSlots = ORE_SLOTS + FUEL_SLOTS
	inv.acceptOre = acceptMap(Recipes)
	inv.acceptFuel = acceptMap(Fuel)
end

local function ensure(id)
	local existing = Inventory(id)
	if existing and existing.type == 'furnace' then
		applyMeta(existing)
		return existing
	end

	local location = locationById(id)
	if not location then return end

	local coords = location.coords
	local inv = Inventory.Create(id, location.label or locale('furnace'), 'furnace', TOTAL_SLOTS, 0, 200000, false, {})

	if not inv then return end

	inv.coords = vec3(coords.x, coords.y, coords.z)
	inv.distance = location.distance or 3.0
	inv.groups = location.groups
	inv.running = false
	inv.processingSlot = nil
	inv.process = nil
	applyMeta(inv)

	return inv
end

local function setRunning(inv, running)
	inv.running = running and true or false

	if not inv.running then
		clearProcess(inv)
	end

	syncViewers(inv)
end

local function allowMove(fromInventory, toInventory, fromSlot, toSlot)
	local function isProcessing(inv, slot)
		return inv.type == 'furnace' and inv.processingSlot == slot
	end

	if isProcessing(fromInventory, fromSlot) or isProcessing(toInventory, toSlot) then
		return false
	end

	if toInventory.type == 'furnace' then
		-- Ore and fuel stay in their own trays; output is take-only.
		local item = fromInventory.items[fromSlot]
		if not item or not slotAccepts(toInventory, toSlot, item.name) then
			return false
		end
	end

	return true
end

CreateThread(function()
	while not shared.ready do Wait(50) end

	buildRecipes()

	for i = 1, #(Config.locations or {}) do
		ensure(Config.locations[i].id)
	end
end)

CreateThread(function()
	while true do
		Wait(200)

		for i = 1, #(Config.locations or {}) do
			local inv = Inventory(Config.locations[i].id)
			if inv and inv.type == 'furnace' and inv.running then
				tickFurnace(inv)
			end
		end
	end
end)

lib.callback.register('ox_inventory:toggleFurnace', function(source, running)
	local playerInv = Inventory(source)
	if not playerInv or not playerInv.open then return false end

	local inv = Inventory(playerInv.open)
	if not inv or inv.type ~= 'furnace' then return false end

	if running == nil then
		running = not inv.running
	end

	setRunning(inv, running)
	return true, inv.running, snapshotProcess(inv)
end)

return {
	ensure = ensure,
	allowMove = allowMove,
	snapshotProcess = snapshotProcess,
	locations = Config.locations or {},
}
