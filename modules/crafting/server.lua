if not lib then return end

local CraftingBenches = {}
local Items = require 'modules.items.server'
local Inventory = require 'modules.inventory.server'

---@param id number | string
---@param data table
local function createCraftingBench(id, data)
	if data.jobs and not data.groups then
		data.groups = data.jobs
	end
	CraftingBenches[id] = {}
	local recipes = data.items

	if recipes then
		for i = 1, #recipes do
			local recipe = recipes[i]
			local item = Items(recipe.name)

			if item then
				recipe.weight = item.weight
				recipe.slot = i
			else
				warn(('failed to setup crafting recipe (bench: %s, slot: %s) - item "%s" does not exist'):format(id, i, recipe.name))
			end

			for ingredient, needs in pairs(recipe.ingredients) do
				if needs < 1 then
					item = Items(ingredient)

					if item and not item.durability then
						item.durability = true
					end
				end
			end
		end

		if shared.target then
			data.points = nil
		else
			data.zones = nil
		end

		CraftingBenches[id] = data
	end
end

local CraftingTechConfig = { requirePreviousItemUnlocked = true, unlockScrapItem = 'scrapmetal' }

local function loadAllBenches()
	local out = {}
	local main = lib.load('data.crafting') or {}
	for i, d in ipairs(main) do out[#out + 1] = d end
	local tech = lib.load('data.crafting_tech') or {}
	CraftingTechConfig.requirePreviousItemUnlocked = (tech.requirePreviousItemUnlocked ~= false)
	CraftingTechConfig.unlockScrapItem = tech.unlockScrapItem or 'scrapmetal'
	for i, d in ipairs(tech) do out[#out + 1] = d end
	return out
end

for i, data in ipairs(loadAllBenches()) do
	createCraftingBench(data.name or data.label or ('bench_%s'):format(i), data)
end

---@param bench table
---@param index number
---@return table?
local function getCraftingGroups(bench, index)
	if shared.target and bench.zones and bench.zones[index] then
		return bench.zones[index].groups or bench.groups
	end
	return bench.groups
end

---falls back to player coords if zones and points are both nil
---@param source number
---@param bench table
---@param index number
---@param research boolean?
---@return vector3
local function getCraftingCoords(source, bench, index, research)
	local list = research and bench.research and bench.research.locations or bench.locations
	if list and list[index] then
		local loc = list[index]
		return (type(loc) == 'table' and loc.coords) or loc
	end
	if not bench.zones and not bench.points then
		return GetEntityCoords(GetPlayerPed(source))
	else
		return shared.target and bench.zones and bench.zones[index] and bench.zones[index].coords or bench.points and bench.points[index]
	end
end

local function recipeNeedsUnlock(recipe)
	return recipe.unlockItem or recipe.unlockXp or (recipe.unlockScrap and recipe.unlockScrap > 0) or false
end

local function getResearchScrap(recipe)
	if recipe.researchScrap and recipe.researchScrap > 0 then return recipe.researchScrap end
	if recipe.unlockScrap and recipe.unlockScrap > 0 then return recipe.unlockScrap end
	return 0
end

local CraftUnlocks = {}
local function getUnlockKey(benchId, recipeSlot) return ('%s_%s'):format(tostring(benchId), tostring(recipeSlot)) end
local function getUnlocks(owner)
	if not owner then return {} end
	if CraftUnlocks[owner] then return CraftUnlocks[owner] end
	local raw = GetResourceKvpString(('ox_craft_unlocks_%s'):format(owner))
	local t = {}
	if raw and raw ~= '' then
		local ok, decoded = pcall(json.decode, raw)
		if ok and type(decoded) == 'table' then t = decoded end
	end
	CraftUnlocks[owner] = t
	return t
end

local function setUnlocked(owner, benchId, recipeSlot, unlocked)
	if not owner then return end
	local u = getUnlocks(owner)
	u[getUnlockKey(benchId, recipeSlot)] = unlocked and true or nil
	SetResourceKvp(('ox_craft_unlocks_%s'):format(owner), json.encode(u))
end

local function isRecipeAllowedByPreviousItem(owner, benchId, recipe)
	if not CraftingTechConfig.requirePreviousItemUnlocked then return true end
	local prevName = type(recipe.previousItem) == 'string' and recipe.previousItem or nil
	if not prevName then return true end
	local bench = CraftingBenches[benchId]
	if not bench or not bench.items then return true end
	local parent
	for slot, rec in ipairs(bench.items) do
		if rec and rec.name == prevName then
			parent = rec
			parent.slot = rec.slot or slot
			break
		end
	end
	if not parent then return true end
	-- Free parent recipes (no blueprint/scrap lock) count as unlocked once their own parents are
	if not recipeNeedsUnlock(parent) then
		return isRecipeAllowedByPreviousItem(owner, benchId, parent)
	end
	return getUnlocks(owner)[getUnlockKey(benchId, parent.slot)] == true
end

local function isRecipeUnlocked(owner, benchId, recipe, recipeId)
	local needUnlock = recipeNeedsUnlock(recipe)
	if needUnlock then
		-- Researched or workbench-unlocked recipes are craftable even if the parent is still locked.
		return getUnlocks(owner)[getUnlockKey(benchId, recipe.slot or recipeId)] == true
	end
	return isRecipeAllowedByPreviousItem(owner, benchId, recipe)
end

lib.callback.register('ox_inventory:openCraftingBench', function(source, id, index, research)
	local left, bench = Inventory(source), CraftingBenches[id]

	if not left then return end

	if bench then
		local groups = getCraftingGroups(bench, index)
		local coords = getCraftingCoords(source, bench, index, research)

		if not coords then return end

		if groups and not server.hasGroup(left, groups) then return end
		if #(GetEntityCoords(GetPlayerPed(source)) - coords) > 10 then return end

		if left.open and left.open ~= source then
			local inv = Inventory(left.open) --[[@as OxInventory]]

			-- Why would the player inventory open with an invalid target? Can't repro but whatever.
			if inv?.player then
				inv:closeInventory()
			end
		end

		left:openInventory()
	end

	return { label = left.label, type = left.type, slots = left.slots, weight = left.weight, maxWeight = left.maxWeight }
end)

---Recipe list with locked/unlocked flags and tree edges for the NUI.
lib.callback.register('ox_inventory:getCraftingBenchData', function(source, benchId, benchIndex, research)
	local left = Inventory(source)
	local bench = CraftingBenches[benchId]
	if not left or not bench or not bench.items then return end

	local groups = getCraftingGroups(bench, benchIndex or 1)
	if groups and not server.hasGroup(left, groups) then return end

	local coords = getCraftingCoords(source, bench, benchIndex or 1, research)
	if coords and #(GetEntityCoords(GetPlayerPed(source)) - coords) > 12 then return end

	local benchTier = bench.tier or 1
	local unlocks = getUnlocks(left.owner)
	local items = {}
	local nameToSlot = {}
	local isTech = false

	for slot, recipe in ipairs(bench.items) do
		if type(recipe) == 'table' then
			local minTier = recipe.tier or 1
			local needUnlock = recipeNeedsUnlock(recipe)
			local key = getUnlockKey(benchId, recipe.slot or slot)
			local unlockedByKvp = (not needUnlock or unlocks[key]) and (minTier <= benchTier)
			local prevName = type(recipe.previousItem) == 'string' and recipe.previousItem or nil
			if prevName or needUnlock then isTech = true end
			items[#items + 1] = {
				name = recipe.name,
				slot = recipe.slot or slot,
				previousItem = prevName,
				ingredients = recipe.ingredients,
				duration = recipe.duration,
				count = recipe.count,
				metadata = recipe.metadata,
				weight = recipe.weight,
				tier = minTier,
				unlockItem = recipe.unlockItem,
				unlockScrap = recipe.unlockScrap,
				researchScrap = getResearchScrap(recipe),
				_unlockedKvp = unlockedByKvp,
			}
			nameToSlot[recipe.name] = #items
		end
	end

	-- Locked recipes unlock independently (research can skip parents).
	for _, it in ipairs(items) do
		it.unlocked = it._unlockedKvp and true or false
		it.locked = not it.unlocked
		it._unlockedKvp = nil
	end

	local treeRootSlots, treeChildren = {}, {}
	for _, it in ipairs(items) do
		local parentIdx = it.previousItem and nameToSlot[it.previousItem] or nil
		local parentSlot = parentIdx and items[parentIdx] and items[parentIdx].slot or nil
		if not parentSlot then
			treeRootSlots[#treeRootSlots + 1] = it.slot
		else
			treeChildren[parentSlot] = treeChildren[parentSlot] or {}
			treeChildren[parentSlot][#treeChildren[parentSlot] + 1] = it.slot
		end
	end

	return {
		label = research and (bench.research and bench.research.label or locale('research_table')) or bench.label or locale('crafting_bench'),
		tier = benchTier,
		items = items,
		slots = #items,
		techTree = isTech,
		researchTable = research and true or nil,
		unlockScrapItem = CraftingTechConfig.unlockScrapItem,
		treeRootSlots = treeRootSlots,
		treeChildren = treeChildren,
	}
end)

local function consumeAndUnlock(left, benchId, recipe, recipeSlot, costs)
	if getUnlocks(left.owner)[getUnlockKey(benchId, recipe.slot or recipeSlot)] then return true end
	if not isRecipeAllowedByPreviousItem(left.owner, benchId, recipe) then return false end
	for i = 1, #costs do
		local cost = costs[i]
		if Inventory.GetItemCount(left, cost.name) < cost.count then return false end
	end
	for i = 1, #costs do
		local cost = costs[i]
		if not Inventory.RemoveItem(left, cost.name, cost.count, nil) then return false end
	end
	setUnlocked(left.owner, benchId, recipe.slot or recipeSlot, true)
	return true
end

lib.callback.register('ox_inventory:unlockCraftRecipe', function(source, benchId, recipeSlot, method)
	local left = Inventory(source)
	local bench = CraftingBenches[benchId]
	if not left or not bench or not bench.items then return false end
	local recipe = bench.items[recipeSlot]
	if not recipe or not recipeNeedsUnlock(recipe) then return false end
	if method == 'scrap' then
		local cost = recipe.unlockScrap
		if not cost or cost < 1 then return false end
		return consumeAndUnlock(left, benchId, recipe, recipeSlot, {
			{ name = CraftingTechConfig.unlockScrapItem, count = cost },
		})
	end
	local need = recipe.unlockItem
	if not need then return false end
	local name, count = need.name or need[1], need.count or need[2] or 1
	return consumeAndUnlock(left, benchId, recipe, recipeSlot, { { name = name, count = count } })
end)

lib.callback.register('ox_inventory:researchCraftRecipe', function(source)
	local left = Inventory(source)
	if not left or not left.open then return false, 'cannot_perform' end

	local tableInv = Inventory(left.open)
	if not tableInv or tableInv.type ~= 'research' then return false, 'cannot_perform' end

	local benchId = tableInv.benchId
	local bench = CraftingBenches[benchId]
	if not bench or not bench.items then return false, 'cannot_perform' end

	if tableInv.coords and #(GetEntityCoords(GetPlayerPed(source)) - tableInv.coords) > 10 then
		return false, 'cannot_perform'
	end

	local slotItem = tableInv.items[1]
	if not slotItem or not slotItem.name then return false, 'ui_research_insert' end

	local recipe
	for slot, rec in ipairs(bench.items) do
		if rec and rec.name == slotItem.name then
			recipe = rec
			recipe.slot = rec.slot or slot
			break
		end
	end
	if not recipe or not recipeNeedsUnlock(recipe) then return false, 'ui_research_cannot' end
	if getUnlocks(left.owner)[getUnlockKey(benchId, recipe.slot)] then return false, 'ui_researched' end

	local scrapItem = CraftingTechConfig.unlockScrapItem
	local scrap = getResearchScrap(recipe)
	if scrap > 0 and Inventory.GetItemCount(left, scrapItem) < scrap then return false, 'recipe_locked' end
	if (slotItem.count or 0) < 1 then return false, 'ui_research_insert' end

	-- Consume the item on the table, then scrap from the player.
	if not Inventory.RemoveItem(tableInv, slotItem.name, 1, nil, 1) then return false, 'cannot_perform' end
	if scrap > 0 and not Inventory.RemoveItem(left, scrapItem, scrap, nil) then return false, 'cannot_perform' end
	setUnlocked(left.owner, benchId, recipe.slot, true)
	return true
end)

local function buildResearchRecipes(owner, benchId)
	local bench = CraftingBenches[benchId]
	local out = {}
	if not bench or not bench.items then return out end
	for slot, recipe in ipairs(bench.items) do
		if recipeNeedsUnlock(recipe) then
			out[recipe.name] = {
				scrap = getResearchScrap(recipe),
				unlocked = getUnlocks(owner)[getUnlockKey(benchId, recipe.slot or slot)] == true,
			}
		end
	end
	return out
end

---One-slot research table inventory (item goes on the table, scrap stays on the player).
local function ensureResearch(benchId, index, owner)
	index = tonumber(index) or 1
	local bench = CraftingBenches[benchId]
	if not bench or not bench.research or not bench.research.locations then return end
	local loc = bench.research.locations[index]
	if not loc then return end

	local coords = (type(loc) == 'table' and loc.coords) or loc
	local id = ('research:%s:%s'):format(tostring(benchId), index)
	local existing = Inventory(id)
	if not existing or existing.type ~= 'research' then
		existing = Inventory.Create(id, bench.research.label or locale('research_table'), 'research', 1, 0, 100000, false, {})
		if not existing then return end
		existing.coords = coords
		existing.distance = 3.0
		existing.groups = bench.groups
		existing.benchId = benchId
		existing.benchIndex = index
	end

	existing.researchRecipes = buildResearchRecipes(owner, benchId)
	existing.unlockScrapItem = CraftingTechConfig.unlockScrapItem
	return existing
end

local TriggerEventHooks = require 'modules.hooks.server'
local GetLocks = require 'modules.locks'

lib.callback.register('ox_inventory:craftItem', function(source, id, index, recipeId, toSlot)
	local left, bench = Inventory(source), CraftingBenches[id]

	if not left then return end

	if bench then
		local groups = getCraftingGroups(bench, index)
		local coords = getCraftingCoords(source, bench, index)

		if groups and not server.hasGroup(left, groups) then return end
		if coords and #(GetEntityCoords(GetPlayerPed(source)) - coords) > 10 then return end

		local recipe = bench.items[recipeId]

		if recipe then
			if not isRecipeUnlocked(left.owner, id, recipe, recipeId) then
				return false, 'recipe_locked'
			end
			local tbl, num = {}, 0

			for name in pairs(recipe.ingredients) do
				num += 1
				tbl[num] = name
			end

			local craftedItem = Items(recipe.name)
			local craftCount = (type(recipe.count) == 'number' and recipe.count) or (table.type(recipe.count) == 'array' and math.random(recipe.count[1], recipe.count[2])) or 1

			-- Modified weight calculation
			local newWeight = left.weight
			local items = Inventory.Search(left, 'slots', tbl) or {}
			---@todo new iterator or something to accept a map
			-- First subtract weight of ingredients that will be removed
			for name, needs in pairs(recipe.ingredients) do
				if needs > 0 then
					local item = Items(name)
					if item then
						newWeight -= (item.weight * needs)
					end
				end
			end

			-- Add weight of crafted item
			newWeight += (craftedItem.weight + (recipe.metadata?.weight or 0)) * craftCount

			if newWeight > left.maxWeight then return false, 'cannot_carry' end

			local items = Inventory.Search(left, 'slots', tbl) or {}
			table.wipe(tbl)

			for name, needs in pairs(recipe.ingredients) do
				if needs == 0 then break end

				local slots = items[name] or items

                if #slots == 0 then return end

				for i = 1, #slots do
					local slot = slots[i]

					if needs == 0 then
						-- Tool presence check; durability gate only when enabled
						if not shared.durability or not slot.metadata.durability or slot.metadata.durability > 0 then
							break
						end
					elseif needs < 1 then
						-- Fractional ingredient = durability wear on a tool
						if not shared.durability then
							tbl[slot.slot] = needs
							break
						end

						local item = Items(name)
						local durability = slot.metadata.durability

						if durability and durability >= needs * 100 then
							if durability > 100 then
								local degrade = (slot.metadata.degrade or item.degrade) * 60
								local percentage = ((durability - os.time()) * 100) / degrade

								if percentage >= needs * 100 then
									tbl[slot.slot] = needs
									break
								end
							else
								tbl[slot.slot] = needs
								break
							end
						end
					elseif needs <= slot.count then
						tbl[slot.slot] = needs
						break
					else
						tbl[slot.slot] = slot.count
						needs -= slot.count
					end

					if needs == 0 then break end
					-- Player does not have enough items (ui should prevent crafting if lacking items, so this shouldn't trigger)
					if needs > 0 and i == #slots then return end
				end
			end

            local lockIds = {}

            for slot in pairs(tbl) do
                lockIds[#lockIds + 1] = ('inventory-%s:slot-%s'):format(left.id, slot)
            end

            local activeSlots <close> = GetLocks(lockIds)

            if not activeSlots then return end

			local hooks <close> = TriggerEventHooks('craftItem', {
				source = source,
				benchId = id,
				benchIndex = index,
				recipe = recipe,
				toInventory = left.id,
				toSlot = toSlot,
			})

			if not hooks.success then return false end

			local success = lib.callback.await('ox_inventory:startCrafting', source, id, recipeId)

			if success then
				for name, needs in pairs(recipe.ingredients) do
					if Inventory.GetItemCount(left, name) < needs then hooks.success = false return end
				end

				for slot, count in pairs(tbl) do
					local invSlot = left.items[slot]

					if not invSlot then hooks.success = false return end

					if count < 1 then
						-- Tool wear via durability; skip entirely when durability is disabled
						if not shared.durability then
							-- Presence-only tool; leave the item untouched
						else
							local item = Items(invSlot.name)
							local durability = invSlot.metadata.durability or 100

							if durability > 100 then
								local degrade = (invSlot.metadata.degrade or item.degrade) * 60
								durability -= degrade * count
							else
								durability -= count * 100
							end

							if invSlot.count > 1 then
								local emptySlot = Inventory.GetEmptySlot(left)

								if emptySlot then
									local ok, newItem = Inventory.SetSlot(left, item, 1, table.deepclone(invSlot.metadata), emptySlot)

									if ok and newItem then
	                                    Items.UpdateDurability(left, newItem --[[@as SlotWithItem]], item, durability < 0 and 0 or durability)
									end
								end

								invSlot.count -= 1
	                            invSlot.weight = Inventory.SlotWeight(item, invSlot)

								left:syncSlotsWithClients({
									{
										item = invSlot,
										inventory = left.id
									}
								}, true)
							else
	                            Items.UpdateDurability(left, invSlot, item, durability < 0 and 0 or durability)
							end
						end
					else
						local removed = invSlot and Inventory.RemoveItem(left, invSlot.name, count, nil, slot)
						-- Failed to remove item (inventory state unexpectedly changed?)
						if not removed then hooks.success = false return end
					end
				end

				Inventory.AddItem(left, craftedItem, craftCount, recipe.metadata or {}, craftedItem.stack and toSlot or nil)
			end

			return success
		end
	end
end)

return {
	ensureResearch = ensureResearch,
}
