if not lib then return end

local Utils = require 'modules.utils.client'
local createBlip = Utils.CreateBlip
local Config = lib.load('data.furnaces') or {}

local points = {}
local prompt = {
	options = { icon = 'fa-fire' },
	message = ('**%s**  \n%s'):format(locale('open_furnace'), locale('interact_prompt', GetControlInstructionalButton(0, 38, true):sub(3)))
}

local FALLBACK_PROP = `prop_hobo_stove_01`

---@param model number|string
---@return number?
local function loadProp(model)
	if type(model) == 'string' then model = joaat(model) end
	if not model or not IsModelInCdimage(model) or not IsModelValid(model) then
		model = FALLBACK_PROP
	end
	if not IsModelInCdimage(model) or not IsModelValid(model) then return end
	return lib.requestModel(model) and model or nil
end

---@param point CPoint
local function spawnFurnace(point)
	if point.entity and DoesEntityExist(point.entity) then return end

	local model = loadProp(point.prop)
	if not model then return end

	local entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, false, false)
	SetEntityHeading(entity, point.heading or 0.0)
	PlaceObjectOnGroundProperly(entity)
	FreezeEntityPosition(entity, true)
	SetEntityCollision(entity, true, true)
	SetModelAsNoLongerNeeded(model)

	point.entity = entity

	if shared.target then
		exports.ox_target:addLocalEntity(entity, {
			{
				name = ('ox_inventory:furnace:%s'):format(point.furnaceId),
				icon = 'fas fa-fire',
				label = locale('open_furnace'),
				distance = point.interactDistance or 2.0,
				onSelect = function()
					client.openInventory('furnace', { id = point.furnaceId })
				end,
			}
		})
	end
end

---@param point CPoint
local function despawnFurnace(point)
	local entity = point.entity
	if not entity then return end

	if shared.target then
		exports.ox_target:removeLocalEntity(entity)
	end

	Utils.DeleteEntity(entity)
	point.entity = nil
end

---@param point CPoint
local function nearbyFurnace(point)
	if shared.target then return end

	if point.isClosest and point.currentDistance < (point.interactDistance or 2.0) then
		if not point.shownPrompt then
			point.shownPrompt = true
			lib.showTextUI(prompt.message, prompt.options)
		end

		if IsControlJustReleased(0, 38) then
			client.openInventory('furnace', { id = point.furnaceId })
		end
	elseif point.shownPrompt then
		point.shownPrompt = false
		lib.hideTextUI()
	end
end

local function wipeFurnaces()
	for i = 1, #points do
		local point = points[i]
		if point.entity then despawnFurnace(point) end
		if point.blip then RemoveBlip(point.blip) end
		if point.remove then point:remove() end
	end

	table.wipe(points)
end

local function createFurnaces()
	wipeFurnaces()

	AddTextEntry('ox_furnace', locale('furnace'))

	for i = 1, #(Config.locations or {}) do
		local location = Config.locations[i]
		local coords = location.coords
		local blip

		if location.blip then
			local settings = table.clone(location.blip)
			settings.name = 'ox_furnace'
			blip = createBlip(settings, coords)
		end

		points[i] = lib.points.new({
			coords = vec3(coords.x, coords.y, coords.z),
			heading = coords.w or 0.0,
			distance = 48,
			prop = location.prop or `prop_hobo_stove_01`,
			furnaceId = location.id,
			inv = 'furnace',
			invId = location.id,
			interactDistance = location.distance or 2.0,
			blip = blip,
			onEnter = spawnFurnace,
			onExit = despawnFurnace,
			nearby = not shared.target and nearbyFurnace or nil,
		})
	end
end

RegisterNetEvent('ox_inventory:furnaceState', function(data)
	SendNUIMessage({ action = 'furnaceState', data = data })
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == shared.resource then wipeFurnaces() end
end)

createFurnaces()

return {
	refresh = createFurnaces,
	wipe = wipeFurnaces,
}
