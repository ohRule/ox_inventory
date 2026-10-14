if not lib then return end

local RECIPES = require 'data.dragcraft'
local Inventory = require 'modules.inventory.server'

---@type table<number, table>
local CraftQueue = {}

local function findRecipe(name1, name2)
	if not name1 or not name2 or name1 == name2 then return end

	local key = ('%s %s'):format(name1, name2)
	if RECIPES[key] then return key, RECIPES[key] end

	key = ('%s %s'):format(name2, name1)
	if RECIPES[key] then return key, RECIPES[key] end

	for id, recipe in pairs(RECIPES) do
		if recipe.costs and recipe.costs[name1] and recipe.costs[name2] then
			return id, recipe
		end
	end
end

---Start a drag-craft if these two slots match a recipe. Returns true if the swap should be cancelled.
---@param data table
---@return boolean
local function tryCraft(data)
	if data.fromType ~= 'player' or data.toType ~= 'player' then return false end

	local fromSlot = data.fromSlot
	local toSlot = data.toSlot

	if type(fromSlot) ~= 'table' or type(toSlot) ~= 'table' then return false end
	if fromSlot.name == toSlot.name then return false end

	local recipeIndex, recipe = findRecipe(fromSlot.name, toSlot.name)
	if not recipe then return false end

	local cost1 = recipe.costs[fromSlot.name]
	local cost2 = recipe.costs[toSlot.name]
	if not cost1 or not cost2 then return false end

	local source = data.source
	local amount1 = cost1.need
	local have1 = Inventory.GetItem(source, fromSlot.name, nil, true) or 0

	if amount1 > have1 then
		TriggerClientEvent('ox_lib:notify', source, {
			type = 'error',
			description = ('Not enough %s. Need %d'):format(fromSlot.label, amount1),
		})
		return true
	end

	local amount2 = cost2.need
	local have2 = Inventory.GetItem(source, toSlot.name, nil, true) or 0

	if amount2 > have2 then
		TriggerClientEvent('ox_lib:notify', source, {
			type = 'error',
			description = ('Not enough %s. Need %d'):format(toSlot.label, amount2),
		})
		return true
	end

	local resultForQueue = {}

	for i = 1, #recipe.result do
		local resultData = recipe.result[i]
		local amount = (resultData.min and resultData.max and math.random(resultData.min, resultData.max))
			or resultData.amount
			or 1

		resultForQueue[i] = {
			name = resultData.name,
			amount = amount,
		}
	end

	CraftQueue[source] = {
		item1 = {
			name = fromSlot.name,
			amount = amount1,
			remove = cost1.remove,
			slot = fromSlot.slot,
		},
		item2 = {
			name = toSlot.name,
			amount = amount2,
			remove = cost2.remove,
			slot = toSlot.slot,
		},
		result = resultForQueue,
		-- What the client's "done" must match: this recipe, and no sooner than its bar
		index = recipeIndex,
		started = GetGameTimer(),
		duration = tonumber(recipe.duration) or 0,
	}

	if recipe.server?.before and recipe.server.before(recipe) == false then
		CraftQueue[source] = nil
		return true
	end

	TriggerClientEvent('dragCraft:Craft', source, recipe.duration, recipeIndex)
	return true
end

local function updateItemDurability(source, craftItem)
	local item = Inventory.GetSlot(source, craftItem.slot)
	if not item then return end

	local durability = item.metadata?.durability or 100
	durability = durability - (100 * craftItem.amount)

	if durability <= 0 then
		Inventory.RemoveItem(source, craftItem.name, 1, nil, item.slot)
	else
		Inventory.SetDurability(source, item.slot, durability)
	end
end

local function wearsTool(craftItem)
	return craftItem.amount > 0 and craftItem.amount < 1
end

---Everything the craft costs is still there: counts for what's used up, the same item in
---its slot for a tool that only wears.
local function canPay(source, queuedCraft)
	for _, craftItem in ipairs({ queuedCraft.item1, queuedCraft.item2 }) do
		if craftItem.remove then
			if wearsTool(craftItem) then
				local item = Inventory.GetSlot(source, craftItem.slot)
				if not item or item.name ~= craftItem.name then return false end
			elseif Inventory.GetItemCount(source, craftItem.name) < craftItem.amount then
				return false
			end
		end
	end

	return true
end

---@param give boolean false to take the used-up costs, true to give them back
local function moveCosts(source, queuedCraft, give)
	for _, craftItem in ipairs({ queuedCraft.item1, queuedCraft.item2 }) do
		if craftItem.remove and not wearsTool(craftItem) then
			if give then
				Inventory.AddItem(source, craftItem.name, craftItem.amount)
			else
				Inventory.RemoveItem(source, craftItem.name, craftItem.amount)
			end
		end
	end
end

RegisterNetEvent('dragCraft:success', function(success, index)
	local source = source
	local queuedCraft = CraftQueue[source]

	if not queuedCraft then return end

	CraftQueue[source] = nil

	-- The client says when the bar is done, so check it's the craft that was started and
	-- that the bar could have run its course
	if not success or index ~= queuedCraft.index then return end
	if GetGameTimer() - queuedCraft.started < queuedCraft.duration * 0.9 then return end

	-- The costs may have been moved, dropped or used during the bar: take them only if
	-- they're all still there, before giving anything
	if not canPay(source, queuedCraft) then
		return TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = locale('cannot_perform') })
	end

	moveCosts(source, queuedCraft, false)

	local given = {}

	for i = 1, #queuedCraft.result do
		local resultData = queuedCraft.result[i]

		if Inventory.AddItem(source, resultData.name, resultData.amount) then
			given[#given + 1] = resultData
		else
			-- No room for it: undo the whole craft
			for j = 1, #given do
				Inventory.RemoveItem(source, given[j].name, given[j].amount)
			end

			moveCosts(source, queuedCraft, true)
			return TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = locale('cannot_carry') })
		end
	end

	for _, craftItem in ipairs({ queuedCraft.item1, queuedCraft.item2 }) do
		if craftItem.remove and wearsTool(craftItem) then
			updateItemDurability(source, craftItem)
		end
	end

	local recipe = RECIPES[queuedCraft.index]

	if recipe?.server?.after then
		recipe.server.after(recipe)
	end
end)

local function addRecipe(source, id, recipe, sync)
	recipe.client = nil
	RECIPES[id] = recipe

	if sync then return end

	lib.callback.await('dragCraft:client:addRecipe', source, id, recipe, true)
end

lib.callback.register('dragCraft:server:addRecipe', addRecipe)
exports('addRecipe', addRecipe)

return {
	tryCraft = tryCraft,
}
