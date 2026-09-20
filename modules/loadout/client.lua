if not lib then return end

local Loadout = require 'modules.loadout.shared'
local Config, Kits, vehicleAllowed = Loadout.Config, Loadout.Kits, Loadout.vehicleAllowed

---@param entity number
---@return boolean
local function isVehicle(entity)
	return DoesEntityExist(entity) and GetEntityType(entity) == 2
end

---@param entity number
---@return boolean
local function canUseLoadout(entity)
	if not isVehicle(entity) then return false end

	for i = 1, #Kits do
		local kit = Kits[i]
		if kit.groups and client.hasGroup(kit.groups) and vehicleAllowed(kit, entity) then
			return true
		end
	end

	return false
end

---@param entity number
---@return boolean
local function canUseArmoury(entity)
	if not isVehicle(entity) then return false end
	return Loadout.getArmoury(entity, client.hasGroup) and true or false
end

---@param entity number
local function openLoadoutMenu(entity)
	if not canUseLoadout(entity) then return end

	local netId = NetworkGetNetworkIdFromEntity(entity)
	local data = lib.callback.await('ox_inventory:getLoadouts', false, netId)
	if not data then return end

	local options = {}

	for i = 1, #data.kits do
		local kit = data.kits[i]
		options[#options + 1] = {
			label = kit.label,
			description = kit.description,
			icon = kit.icon or 'gun',
			args = { kit = kit.id },
		}
	end

	if #options == 0 then
		return lib.notify({ type = 'error', description = locale('loadout_unavailable') })
	end

	options[#options + 1] = {
		label = locale('return_loadout'),
		description = locale('return_loadout_desc'),
		icon = 'box-open',
		args = { returnLoadout = true },
	}

	lib.registerMenu({
		id = 'ox_inventory_loadout',
		title = locale('loadouts'),
		position = 'top-right',
		options = options,
	}, function(_, _, args)
		if args.returnLoadout then
			TriggerServerEvent('ox_inventory:returnLoadout', netId)
		elseif args.kit then
			TriggerServerEvent('ox_inventory:giveLoadout', args.kit, netId)
		end
	end)

	lib.showMenu('ox_inventory_loadout')
end

local function registerTarget()
	local distance = Config.distance or 2.5

	exports.ox_target:addGlobalVehicle({
		{
			name = 'ox_inventory_loadout',
			icon = 'fa-solid fa-gun',
			label = locale('select_loadout'),
			distance = distance,
			canInteract = canUseLoadout,
			onSelect = function(data)
				openLoadoutMenu(data.entity)
			end,
		},
		{
			name = 'ox_inventory_armoury',
			icon = 'fa-solid fa-warehouse',
			label = locale('vehicle_armoury'),
			distance = distance,
			canInteract = canUseArmoury,
			onSelect = function(data)
				if not canUseArmoury(data.entity) then return end
				client.openInventory('armoury', { netid = NetworkGetNetworkIdFromEntity(data.entity) })
			end,
		},
	})
end

if shared.target or GetResourceState('ox_target') == 'started' then
	registerTarget()
end
