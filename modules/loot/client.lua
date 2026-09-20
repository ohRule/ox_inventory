if not lib then return end

local Utils = require 'modules.utils.client'
local Config = lib.load('data.lootprops') or {}

local points = {}
local prompt = {
	options = { icon = 'fa-box-open' },
	message = ('**%s**  \n%s'):format(locale('open_loot'), locale('interact_prompt', GetControlInstructionalButton(0, 38, true):sub(3)))
}

---@param point CPoint
local function spawnLoot(point)
	if point.entity and DoesEntityExist(point.entity) then return end

	local model = lib.requestModel(point.prop)
	if not model then return end

	local entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, false, false)
	SetEntityHeading(entity, point.heading or 0.0)
	PlaceObjectOnGroundProperly(entity)
	FreezeEntityPosition(entity, true)
	SetEntityCollision(entity, true, true)
	SetEntityAsMissionEntity(entity, true, true)
	SetModelAsNoLongerNeeded(model)
	point.entity = entity

	if shared.target then
		exports.ox_target:addLocalEntity(entity, {
			{
				name = ('ox_inventory:loot:%s'):format(point.lootId),
				icon = 'fas fa-box-open',
				label = locale('open_loot'),
				distance = point.interactDistance or 1.8,
				onSelect = function()
					client.openInventory('lootprop', { id = point.lootId })
				end,
			}
		})
	end
end

---@param point CPoint
local function despawnLoot(point)
	local entity = point.entity
	if not entity then return end

	if shared.target then
		exports.ox_target:removeLocalEntity(entity)
	end

	Utils.DeleteEntity(entity)
	point.entity = nil
end

---@param point CPoint
local function nearbyLoot(point)
	if point.isClosest and point.currentDistance < (point.interactDistance or 1.8) then
		if not point.shownPrompt then
			point.shownPrompt = true
			lib.showTextUI(prompt.message, prompt.options)
		end

		if IsControlJustReleased(0, 38) then
			client.openInventory('lootprop', { id = point.lootId })
		end
	elseif point.shownPrompt then
		point.shownPrompt = false
		lib.hideTextUI()
	end
end

local function wipeLoot()
	for i = 1, #points do
		local point = points[i]
		if point.entity then despawnLoot(point) end
		if point.remove then point:remove() end
	end
	table.wipe(points)
end

local function createLoot()
	wipeLoot()

	for i = 1, #(Config.locations or {}) do
		local location = Config.locations[i]
		local coords = location.coords

		points[i] = lib.points.new({
			coords = vec3(coords.x, coords.y, coords.z),
			heading = coords.w or 0.0,
			distance = 48,
			prop = location.prop,
			lootId = location.id,
			inv = 'lootprop',
			invId = location.id,
			interactDistance = location.distance or 1.8,
			onEnter = spawnLoot,
			onExit = despawnLoot,
			nearby = not shared.target and nearbyLoot or nil,
		})
	end
end

RegisterNetEvent('ox_inventory:lootSearch', function(data)
	SendNUIMessage({ action = 'lootSearch', data = data })
end)

RegisterNetEvent('ox_inventory:lootSearchDone', function(data)
	SendNUIMessage({ action = 'lootSearchDone', data = data })
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == shared.resource then wipeLoot() end
end)

createLoot()

return {
	refresh = createLoot,
	wipe = wipeLoot,
}
