if not lib then return end

local Items = require 'modules.items.server'
local Inventory = require 'modules.inventory.server'
local TriggerEventHooks = require 'modules.hooks.server'
local GetLocks = require 'modules.locks'

local Recipes = {}

do
	local data = lib.load('data.quickcraft') or {}

	for i = 1, #data do
		local recipe = data[i]
		local item = Items(recipe.name)

		if item then
			Recipes[i] = {
				id = i,
				name = recipe.name,
				label = recipe.label or item.label,
				category = recipe.category or 'tools',
				ingredients = recipe.ingredients or {},
				duration = recipe.duration or 3000,
				count = recipe.count or 1,
				metadata = recipe.metadata,
				weight = item.weight,
			}
		else
			warn(('failed to setup quickcraft recipe #%s - item "%s" does not exist'):format(i, recipe.name))
		end
	end
end

---Recipe list sent to the NUI on init
---@return table
local function getRecipes()
	local list = {}

	for i = 1, #Recipes do
		list[i] = Recipes[i]
	end

	return list
end

exports('GetQuickCraftRecipes', getRecipes)

lib.callback.register('ox_inventory:getQuickCraftRecipes', function()
	return getRecipes()
end)

---Validate ingredients, run client progress, consume, and give the result
lib.callback.register('ox_inventory:quickCraftItem', function(source, recipeId)
	local left = Inventory(source)
	local recipe = Recipes[recipeId]

	if not left or not recipe then return false end

	local craftedItem = Items(recipe.name)
	if not craftedItem then return false end

	local craftCount = (type(recipe.count) == 'number' and recipe.count)
		or (table.type(recipe.count) == 'array' and math.random(recipe.count[1], recipe.count[2]))
		or 1

	local ingredientNames, num = {}, 0
	for name in pairs(recipe.ingredients) do
		num += 1
		ingredientNames[num] = name
	end

	-- Weight check after removing ingredients and adding result
	local newWeight = left.weight
	for name, needs in pairs(recipe.ingredients) do
		if needs > 0 then
			local item = Items(name)
			if item then
				newWeight -= (item.weight * needs)
			end
		end
	end
	newWeight += (craftedItem.weight + (recipe.metadata?.weight or 0)) * craftCount

	if newWeight > left.maxWeight then return false, 'cannot_carry' end

	local items = Inventory.Search(left, 'slots', ingredientNames) or {}
	local consume = {}

	for name, needs in pairs(recipe.ingredients) do
		local slots = items[name] or items

		if type(slots) ~= 'table' or #slots == 0 then return false end

		if needs == 0 then
			local ok
			for i = 1, #slots do
				local slot = slots[i]
				-- Tool must exist; durability > 0 only required when system is on
				if not shared.durability or not slot.metadata.durability or slot.metadata.durability > 0 then
					ok = true
					break
				end
			end
			if not ok then return false end
		elseif needs < 1 then
			local found
			for i = 1, #slots do
				local slot = slots[i]
				if not shared.durability then
					-- Presence-only when durability is disabled
					consume[slot.slot] = needs
					found = true
					break
				end
				local durability = slot.metadata.durability
				if durability and durability >= needs * 100 then
					consume[slot.slot] = needs
					found = true
					break
				end
			end
			if not found then return false end
		else
			local remaining = needs
			for i = 1, #slots do
				local slot = slots[i]
				if remaining <= slot.count then
					consume[slot.slot] = remaining
					remaining = 0
					break
				else
					consume[slot.slot] = slot.count
					remaining -= slot.count
				end
			end
			if remaining > 0 then return false end
		end
	end

	local lockIds = {}
	for slot in pairs(consume) do
		lockIds[#lockIds + 1] = ('inventory-%s:slot-%s'):format(left.id, slot)
	end

	local activeSlots <close> = GetLocks(lockIds)
	if not activeSlots then return false end

	local hooks <close> = TriggerEventHooks('quickCraftItem', {
		source = source,
		recipe = recipe,
		toInventory = left.id,
	})

	if not hooks.success then return false end

	local success = lib.callback.await('ox_inventory:startQuickCraft', source, recipeId)
	if not success then return false end

	-- Re-validate counts after the progress bar
	for name, needs in pairs(recipe.ingredients) do
		if needs >= 1 and Inventory.GetItemCount(left, name) < needs then
			hooks.success = false
			return false
		end
	end

	for slot, count in pairs(consume) do
		local invSlot = left.items[slot]
		if not invSlot then
			hooks.success = false
			return false
		end

		if count < 1 then
			-- Skip tool wear when durability is disabled
			if shared.durability then
				local item = Items(invSlot.name)
				local durability = invSlot.metadata.durability or 100

				if durability > 100 then
					local degrade = (invSlot.metadata.degrade or item.degrade) * 60
					durability -= degrade * count
				else
					durability -= count * 100
				end

				Items.UpdateDurability(left, invSlot, item, durability < 0 and 0 or durability)
			end
		else
			local removed = Inventory.RemoveItem(left, invSlot.name, count, nil, slot)
			if not removed then
				hooks.success = false
				return false
			end
		end
	end

	Inventory.AddItem(left, craftedItem, craftCount, recipe.metadata or {})

	return true
end)
