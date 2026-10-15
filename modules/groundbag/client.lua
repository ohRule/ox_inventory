if not lib then return end

-- Bags on the ground (modules/gear/server.lua: a worn bag that fell off a player). Each game
-- draws the bag where it lies, with a target to open it or to pick it up, kneeling for a
-- few seconds as in Rust (data/gear.lua's `ground`). Without ox_target, E opens it and G
-- picks it up.

local Utils = require 'modules.utils.client'
local Config = lib.load('data.gear') or {}
local ground = Config.ground or {}
local REACH = ground.reach or 2.0
local KNEEL = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 1 }

local points = {} -- [bag id] = point
local busy = false

local function open(point)
	client.openInventory('container', { groundBag = point.bagId })
end

local function pickUp(point)
	if busy then return end
	busy = true

	local duration = lib.callback.await('ox_inventory:groundBagPickupStart', false, point.bagId)

	if not duration then
		busy = false
		return lib.notify({ id = 'ground_bag', type = 'error', description = locale('ground_bag_gone') })
	end

	local done = lib.progressBar({
		duration = duration,
		label = locale('ground_bag_picking', point.label),
		useWhileDead = false,
		canCancel = true,
		disable = { move = true, car = true, combat = true },
		anim = KNEEL,
	})

	if done then
		local ok, why = lib.callback.await('ox_inventory:groundBagPickup', false, point.bagId)

		if not ok and why then
			lib.notify({ id = 'ground_bag', type = 'error', description = locale(why) })
		end
	end

	busy = false
end

---@param point CPoint
local function spawn(point)
	if point.entity and DoesEntityExist(point.entity) then return end
	if point.instance and point.instance ~= LocalPlayer.state.instance then return end

	local model = point.model or client.dropmodel

	if not IsModelValid(model) and not IsModelInCdimage(model) then
		model = client.dropmodel
	end

	if not pcall(lib.requestModel, model, 5000) then return end

	local entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, false, false)
	SetModelAsNoLongerNeeded(model)
	PlaceObjectOnGroundProperly(entity)
	FreezeEntityPosition(entity, true)
	SetEntityCollision(entity, true, true)
	point.entity = entity

	if shared.target then
		exports.ox_target:addLocalEntity(entity, {
			{
				name = 'ox_inventory:groundbag:open',
				icon = 'fas fa-box-open',
				label = locale('ground_bag_open', point.label),
				distance = REACH,
				onSelect = function() open(point) end,
			},
			{
				name = 'ox_inventory:groundbag:pickup',
				icon = 'fas fa-hand',
				label = locale('ground_bag_pickup', point.label),
				distance = REACH,
				onSelect = function() CreateThread(function() pickUp(point) end) end,
			},
		})
	end
end

---@param point CPoint
local function despawn(point)
	if point.shownPrompt then
		point.shownPrompt = false
		lib.hideTextUI()
	end

	local entity = point.entity
	if not entity then return end

	if shared.target then
		exports.ox_target:removeLocalEntity(entity)
	end

	Utils.DeleteEntity(entity)
	point.entity = nil
end

---Without ox_target: E opens it, G picks it up.
---@param point CPoint
local function nearby(point)
	if point.isClosest and point.currentDistance < REACH and point.entity then
		if not point.shownPrompt then
			point.shownPrompt = true
			lib.showTextUI(locale('ground_bag_prompt', point.label), { icon = 'fa-box-open' })
		end

		if IsControlJustReleased(0, 38) then
			open(point)
		elseif IsControlJustReleased(0, 47) then
			CreateThread(function() pickUp(point) end)
		end
	elseif point.shownPrompt then
		point.shownPrompt = false
		lib.hideTextUI()
	end
end

---The bags on the ground, as the server has them (GlobalState.oxGroundBags).
local function refresh(list)
	local seen = {}

	for _, bag in ipairs(list or {}) do
		seen[bag.id] = true

		if not points[bag.id] then
			points[bag.id] = lib.points.new({
				coords = vec3(bag.x, bag.y, bag.z),
				distance = 40,
				bagId = bag.id,
				label = bag.label,
				model = bag.model,
				instance = bag.instance,
				onEnter = spawn,
				onExit = despawn,
				nearby = not shared.target and nearby or nil,
			})
		end
	end

	for id, point in pairs(points) do
		if not seen[id] then
			despawn(point)
			point:remove()
			points[id] = nil
		end
	end
end

AddStateBagChangeHandler('oxGroundBags', 'global', function(_, _, value)
	refresh(value)
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= shared.resource then return end

	for _, point in pairs(points) do despawn(point) end
end)

refresh(GlobalState.oxGroundBags)
