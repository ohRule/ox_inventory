if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items = require 'modules.items.server'
local Config = lib.load('data.recyclers') or {}

local INPUT_SLOTS = 6
local OUTPUT_SLOTS = 6
local TOTAL_SLOTS = INPUT_SLOTS + OUTPUT_SLOTS
local DEFAULT_DURATION = 5000

---@type table<string, { duration: number, consume: number, output: table<string, number> }>
local Recipes = {}

local function scrapFromWeight(weight)
	return math.max(1, math.floor((weight or 500) / 400))
end

local function buildRecipes()
	table.wipe(Recipes)

	if Config.recycleWeapons then
		for name, item in pairs(Items()) do
			if item.weapon then
				Recipes[name] = {
					duration = 8000,
					consume = 1,
					output = { scrapmetal = scrapFromWeight(item.weight) },
				}
			end
		end
	end

	if Config.recycleAmmo then
		for name in pairs(Items()) do
			if name:sub(1, 5) == 'ammo-' or name:sub(1, 7) == 'bullet-' or name:sub(1, 6) == 'empty_' then
				Recipes[name] = {
					duration = 3000,
					consume = 1,
					output = { scrapmetal = 1 },
				}
			end
		end
	end

	for name, recipe in pairs(Config.recipes or {}) do
		Recipes[name] = {
			duration = recipe.duration or DEFAULT_DURATION,
			consume = recipe.consume or 1,
			output = recipe.output or { scrapmetal = 1 },
		}
	end
end

---@param id string
local function locationById(id)
	for i = 1, #(Config.locations or {}) do
		local location = Config.locations[i]
		if location.id == id then return location end
	end
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
		remaining = inv.process.blocked and 0 or remaining,
		blocked = inv.process.blocked or false,
	}
end

---@param inv OxInventory
local function syncViewers(inv)
	local payload = {
		running = inv.running and true or false,
		process = snapshotProcess(inv),
	}

	for playerId in pairs(inv.openedBy) do
		TriggerClientEvent('ox_inventory:recyclerState', playerId, payload)
	end
end

---@param inv OxInventory
local function clearProcess(inv)
	inv.processingSlot = nil
	inv.process = nil
end

---@param inv OxInventory
---@param slot number
---@param item SlotWithItem
---@param recipe table
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
	}
	syncViewers(inv)
end

---Only place recycled goods into output slots (never back into input).
---@param inv OxInventory
---@param name string
---@param count number
---@return boolean
local function addToOutput(inv, name, count)
	local item = Items(name)
	if not item then return false end

	if item.stack then
		for slot = INPUT_SLOTS + 1, inv.slots do
			local slotData = inv.items[slot]
			if slotData and slotData.name == name then
				local success = Inventory.AddItem(inv, name, count, nil, slot)
				return success and true or false
			end
		end
	end

	for slot = INPUT_SLOTS + 1, inv.slots do
		if not inv.items[slot] then
			local success = Inventory.AddItem(inv, name, count, nil, slot)
			return success and true or false
		end
	end

	return false
end

---@param inv OxInventory
---@param outputs table<string, number>
---@return boolean
local function canFitOutputs(inv, outputs)
	local occupied = {}

	for slot = INPUT_SLOTS + 1, inv.slots do
		local slotData = inv.items[slot]
		occupied[slot] = slotData and { name = slotData.name } or false
	end

	for name in pairs(outputs) do
		local item = Items(name)
		if not item then return false end

		local placed = false

		if item.stack then
			for slot = INPUT_SLOTS + 1, inv.slots do
				if occupied[slot] and occupied[slot].name == name then
					placed = true
					break
				end
			end
		end

		if not placed then
			for slot = INPUT_SLOTS + 1, inv.slots do
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

---@param inv OxInventory
---@return number?, table?, table?
local function nextInput(inv)
	for slot = 1, INPUT_SLOTS do
		local item = inv.items[slot]
		-- Don't shred bags/containers (contents would vanish)
		if item and not (item.metadata and item.metadata.container) then
			local recipe = Recipes[item.name]
			if recipe then
				return slot, item, recipe
			end
		end
	end
end

---@param inv OxInventory
local function tickRecycler(inv)
	if not inv.running then return end

	-- Resume or start the current input
	if not inv.processingSlot then
		local slot, item, recipe = nextInput(inv)
		if not slot then return end
		beginProcess(inv, slot, item, recipe)
		return
	end

	local process = inv.process
	local slot = inv.processingSlot
	local item = inv.items[slot]

	-- Item was removed somehow
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
	if take < 1 then
		clearProcess(inv)
		syncViewers(inv)
		return
	end

	Inventory.RemoveItem(inv, item.name, take, nil, slot)

	for name, count in pairs(recipe.output) do
		addToOutput(inv, name, count)
	end

	clearProcess(inv)

	-- Chain immediately into the next valid input
	local nextSlot, nextItem, nextRecipe = nextInput(inv)
	if nextSlot then
		beginProcess(inv, nextSlot, nextItem, nextRecipe)
	else
		syncViewers(inv)
	end
end

---@param id string
---@return OxInventory?
local function ensure(id)
	local existing = Inventory(id)
	if existing and existing.type == 'recycler' then return existing end

	local location = locationById(id)
	if not location then return end

	local coords = location.coords
	local inv = Inventory.Create(id, location.label or locale('recycler'), 'recycler', TOTAL_SLOTS, 0, 200000, false, {})

	if not inv then return end

	inv.coords = vec3(coords.x, coords.y, coords.z)
	inv.distance = location.distance or 3.0
	inv.groups = location.groups
	inv.inputSlots = INPUT_SLOTS
	inv.running = false
	inv.processingSlot = nil
	inv.process = nil

	return inv
end

local function setRunning(inv, running)
	inv.running = running and true or false

	if not inv.running then
		clearProcess(inv)
	end

	syncViewers(inv)
end

---Block deposits into output slots and the item currently being shredded.
local function allowMove(fromInventory, toInventory, fromSlot, toSlot)
	local function isProcessing(inv, slot)
		return inv.type == 'recycler' and inv.processingSlot == slot
	end

	if isProcessing(fromInventory, fromSlot) or isProcessing(toInventory, toSlot) then
		return false
	end

	if toInventory.type == 'recycler' and toSlot > (toInventory.inputSlots or INPUT_SLOTS) then
		-- Output is take-only (Rust: you pull recycled mats out, you don't dump into it)
		return false
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
			if inv and inv.type == 'recycler' and inv.running then
				tickRecycler(inv)
			end
		end
	end
end)

lib.callback.register('ox_inventory:toggleRecycler', function(source, running)
	local playerInv = Inventory(source)
	if not playerInv or not playerInv.open then return false end

	local inv = Inventory(playerInv.open)
	if not inv or inv.type ~= 'recycler' then return false end

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
