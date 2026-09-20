if not lib then return end

local CraftingBenches = {}
local Items = require 'modules.items.client'
local createBlip = require 'modules.utils.client'.CreateBlip
local Utils = require 'modules.utils.client'
local prompt = {
    options = { icon = 'fa-wrench' },
    message = ('**%s**  \n%s'):format(locale('open_crafting_bench'), locale('interact_prompt', GetControlInstructionalButton(0, 38, true):sub(3)))
}
local researchPrompt = {
    options = { icon = 'fa-flask' },
    message = ('**%s**  \n%s'):format(locale('open_research_table'), locale('interact_prompt', GetControlInstructionalButton(0, 38, true):sub(3)))
}

---@param id number
---@param data table
local function createCraftingBench(id, data)
	CraftingBenches[id] = {}
	local recipes = data.items

	if recipes then
		data.slots = #recipes

		for i = 1, data.slots do
			local recipe = recipes[i]
			local item = Items[recipe.name]

			if item then
				recipe.weight = item.weight
				recipe.slot = i
			else
				warn(('failed to setup crafting recipe (bench: %s, slot: %s) - item "%s" does not exist'):format(id, i, recipe.name))
			end
		end

		local blip = data.blip

		if blip then
			blip.name = blip.name or ('ox_crafting_%s'):format(data.label and id or 0)
			AddTextEntry(blip.name, data.label or locale('crafting_bench'))
		end

		if shared.target then
			data.points = nil
            if data.zones then
    			for i = 1, #data.zones do
    				local zone = data.zones[i]
    				zone.name = ('craftingbench_%s:%s'):format(id, i)
    				zone.id = id
    				zone.index = i
    				zone.options = {
						{
    						label = zone.label or locale('open_crafting_bench'),
    						canInteract = (zone.groups or data.groups) and function()
    							return client.hasGroup(zone.groups or data.groups)
    						end or nil,
    						onSelect = function()
    							client.openInventory('crafting', { id = id, index = i })
    						end,
    						distance = zone.distance or 2.0,
    						icon = zone.icon or 'fas fa-wrench',
    					}
    				}

    				exports.ox_target:addBoxZone(zone)

    				if blip then
    					createBlip(blip, zone.coords)
    				end
    			end
            end
		elseif data.points then
			data.zones = nil

			for i = 1, #data.points do
				local coords = data.points[i]

				lib.points.new({
					coords = coords,
					distance = 16,
					benchid = id,
					index = i,
					inv = 'crafting',
                    prompt = prompt,
                    marker = client.craftingmarker,
					nearby = Utils.nearbyMarker
				})

				if blip then
					createBlip(blip, coords)
				end
			end
		end

		CraftingBenches[id] = data
	end
end

local function loadAllBenches()
	local out = {}
	local main = lib.load('data.crafting') or {}
	for i, d in ipairs(main) do out[#out + 1] = d end
	local tech = lib.load('data.crafting_tech') or {}
	for i, d in ipairs(tech) do out[#out + 1] = d end
	return out
end

for _, data in ipairs(loadAllBenches()) do
	createCraftingBench(data.name or data.label or ('bench_%s'):format(#CraftingBenches + 1), data)
end

-- Spawn configured benches after load so this require doesn't block NUI callbacks.
local PreplacedBenchEntities = {}

local function spawnLocation(benchId, benchData, loc, i, research)
	local coords = (type(loc) == 'table' and loc.coords) or loc
	if not coords then return end

	local researchCfg = benchData.research
	local heading = (type(loc) == 'table' and loc.heading) or 0.0
	local propName = (type(loc) == 'table' and loc.prop)
		or (research and researchCfg and researchCfg.prop)
		or benchData.prop
	local blip = research and researchCfg and researchCfg.blip or (not research and benchData.blip) or nil
	local icon = research and 'fas fa-flask' or (benchData.icon or 'fas fa-wrench')

	if not shared.target then
		lib.points.new({
			coords = coords,
			distance = 16,
			benchid = benchId,
			id = benchId,
			index = i,
			inv = research and 'research' or 'crafting',
			research = research or nil,
			prompt = research and researchPrompt or prompt,
			marker = client.craftingmarker,
			nearby = Utils.nearbyMarker,
		})
		if blip then
			blip.name = blip.name or (research and ('ox_research_%s'):format(benchId) or ('ox_crafting_%s'):format(benchId))
			AddTextEntry(blip.name, research and locale('research_table') or (benchData.label or locale('crafting_bench')))
			createBlip(blip, coords)
		end
		return
	end

	if type(propName) ~= 'string' or not lib.requestModel(propName) then return end

	local modelHash = joaat(propName)
	local obj = CreateObject(modelHash, coords.x, coords.y, coords.z, false, false, false)
	if not obj or obj == 0 then return end

	SetEntityHeading(obj, heading)
	FreezeEntityPosition(obj, true)
	SetEntityInvincible(obj, true)
	SetBlockingOfNonTemporaryEvents(obj, true)
	PlaceObjectOnGroundProperly(obj)
	SetModelAsNoLongerNeeded(modelHash)

	local benchIndex = i
	exports.ox_target:addLocalEntity(obj, {
		{
			name = ('craftingbench_preplaced_%s_%s_%s'):format(tostring(benchId), i, research and 'r' or 'c'),
			icon = icon,
			label = research and locale('open_research_table') or (benchData.label or locale('open_crafting_bench')),
			distance = 2.0,
			canInteract = benchData.groups and function()
				return client.hasGroup(benchData.groups)
			end or nil,
			onSelect = function()
				if research then
					client.openInventory('research', { id = benchId, index = benchIndex })
				else
					client.openInventory('crafting', { id = benchId, index = benchIndex })
				end
			end,
		},
	})
	PreplacedBenchEntities[#PreplacedBenchEntities + 1] = obj
	if blip then
		blip.name = blip.name or (research and ('ox_research_%s'):format(benchId) or ('ox_crafting_%s'):format(benchId))
		AddTextEntry(blip.name, research and locale('research_table') or (benchData.label or locale('crafting_bench')))
		createBlip(blip, coords)
	end
end

CreateThread(function()
	if shared.target then Wait(500) end

	for benchId, benchData in pairs(CraftingBenches) do
		local locations = benchData.locations
		if locations then
			for i, loc in ipairs(locations) do
				spawnLocation(benchId, benchData, loc, i, false)
			end
		end
		local researchLocs = benchData.research and benchData.research.locations
		if researchLocs then
			for i, loc in ipairs(researchLocs) do
				spawnLocation(benchId, benchData, loc, i, true)
			end
		end
	end
end)

AddEventHandler('onResourceStop', function(resName)
	if GetCurrentResourceName() ~= resName then return end
	for _, ent in ipairs(PreplacedBenchEntities) do
		if ent and DoesEntityExist(ent) then
			pcall(function() exports.ox_target:removeLocalEntity(ent) end)
			DeleteEntity(ent)
		end
	end
end)

return CraftingBenches
