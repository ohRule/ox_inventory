if not lib then return end

local Utils = require 'modules.utils.client'
local createBlip = Utils.CreateBlip
local Config = lib.load('data.recyclers') or {}

local points = {}
local prompt = {
	options = { icon = 'fa-recycle' },
	message = ('**%s**  \n%s'):format(locale('open_recycler'), locale('interact_prompt', GetControlInstructionalButton(0, 38, true):sub(3)))
}

---@param point CPoint
local function spawnRecycler(point)
	if point.entity and DoesEntityExist(point.entity) then return end

	local model = lib.requestModel(point.prop)
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
				name = ('ox_inventory:recycler:%s'):format(point.recyclerId),
				icon = 'fas fa-recycle',
				label = locale('open_recycler'),
				distance = point.interactDistance or 2.0,
				onSelect = function()
					client.openInventory('recycler', { id = point.recyclerId })
				end,
			}
		})
	end
end

---@param point CPoint
local function despawnRecycler(point)
	local entity = point.entity
	if not entity then return end

	if shared.target then
		exports.ox_target:removeLocalEntity(entity)
	end

	Utils.DeleteEntity(entity)
	point.entity = nil
end

---@param point CPoint
local function nearbyRecycler(point)
	if shared.target then return end

	if point.isClosest and point.currentDistance < (point.interactDistance or 2.0) then
		if not point.shownPrompt then
			point.shownPrompt = true
			lib.showTextUI(prompt.message, prompt.options)
		end

		if IsControlJustReleased(0, 38) then
			client.openInventory('recycler', { id = point.recyclerId })
		end
	elseif point.shownPrompt then
		point.shownPrompt = false
		lib.hideTextUI()
	end
end

local function wipeRecyclers()
	for i = 1, #points do
		local point = points[i]
		if point.entity then despawnRecycler(point) end
		if point.blip then RemoveBlip(point.blip) end
		if point.remove then point:remove() end
	end

	table.wipe(points)
end

local function createRecyclers()
	wipeRecyclers()

	AddTextEntry('ox_recycler', locale('recycler'))

	for i = 1, #(Config.locations or {}) do
		local location = Config.locations[i]
		local coords = location.coords
		local blip

		if location.blip then
			local settings = table.clone(location.blip)
			settings.name = 'ox_recycler'
			blip = createBlip(settings, coords)
		end

		points[i] = lib.points.new({
			coords = vec3(coords.x, coords.y, coords.z),
			heading = coords.w or 0.0,
			distance = 48,
			prop = location.prop or `prop_recyclebin_05_a`,
			recyclerId = location.id,
			inv = 'recycler',
			invId = location.id,
			interactDistance = location.distance or 2.0,
			blip = blip,
			onEnter = spawnRecycler,
			onExit = despawnRecycler,
			nearby = not shared.target and nearbyRecycler or nil,
		})
	end
end

RegisterNetEvent('ox_inventory:recyclerState', function(data)
	SendNUIMessage({ action = 'recyclerState', data = data })
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == shared.resource then wipeRecyclers() end
end)

createRecyclers()

return {
	refresh = createRecyclers,
	wipe = wipeRecyclers,
}
