if not lib then return end

local Utils = require 'modules.utils.client'
local Items = require 'modules.items.client'
local Config = lib.load('data.attachments') or {}

local boneIds = {
	SKEL_ROOT = 0,
	SKEL_Pelvis = 11816,
	SKEL_Spine_Root = 5757,
	SKEL_Spine3 = 24818,
	SKEL_Spine2 = 24817,
	SKEL_Spine1 = 24816,
	SKEL_Neck_1 = 39317,
	SKEL_Head = 31086,
	SKEL_L_Clavicle = 64729,
	SKEL_R_Clavicle = 10706,
	SKEL_L_UpperArm = 45509,
	SKEL_R_UpperArm = 40269,
	SKEL_L_Forearm = 61163,
	SKEL_R_Forearm = 28252,
	SKEL_L_Hand = 18905,
	SKEL_R_Hand = 57005,
	SKEL_L_Thigh = 58271,
	SKEL_R_Thigh = 51826,
	SKEL_L_Calf = 63931,
	SKEL_R_Calf = 36864,
	SKEL_L_Foot = 14201,
	SKEL_R_Foot = 52301,
}

-- serverId -> itemName -> { entity, signature, pending }
local attached = {}

local function resolveBone(ped, bone)
	if type(bone) == 'number' then
		return GetPedBoneIndex(ped, bone)
	end

	local id = boneIds[bone]
	if id then
		return GetPedBoneIndex(ped, id)
	end

	return GetEntityBoneIndexByName(ped, bone)
end

local function componentSignature(meta)
	meta = meta or {}
	local comps = meta.components
	local list = ''

	if comps then
		for i = 1, #comps do
			list = list .. tostring(comps[i]) .. ','
		end
	end

	return ('%s:%s:%s'):format(list, meta.specialAmmo or '', meta.tint or '')
end

-- Apply the same suppressor/mag/tint metadata used when the weapon is in-hand.
local function applyWeaponComponents(entity, weaponHash, meta, itemName)
	if not meta then return end

	if meta.components then
		for i = 1, #meta.components do
			local item = Items(meta.components[i])
			local list = item and item.client and item.client.component
			if list then
				for v = 1, #list do
					local component = list[v]
					if DoesWeaponTakeWeaponComponent(weaponHash, component) then
						GiveWeaponComponentToWeaponObject(entity, component)
					end
				end
			end
		end
	end

	if meta.specialAmmo then
		local item = Items(itemName)
		local modelName = item and item.model or itemName
		local clipComponentKey = ('%s_CLIP'):format(tostring(modelName):gsub('WEAPON_', 'COMPONENT_'))
		local specialClip = ('%s_%s'):format(clipComponentKey, meta.specialAmmo:upper())

		if DoesWeaponTakeWeaponComponent(weaponHash, specialClip) then
			GiveWeaponComponentToWeaponObject(entity, specialClip)
		end
	end

	if meta.tint then
		SetWeaponObjectTintIndex(entity, meta.tint)
	end
end

local function deleteAttachment(serverId, name)
	local byPlayer = attached[serverId]
	if not byPlayer then return end

	local data = byPlayer[name]
	if not data then return end

	if data.entity then
		Utils.DeleteEntity(data.entity)
	end

	byPlayer[name] = nil

	if not next(byPlayer) then
		attached[serverId] = nil
	end
end

local function clearPlayer(serverId)
	local byPlayer = attached[serverId]
	if not byPlayer then return end

	for name in pairs(byPlayer) do
		deleteAttachment(serverId, name)
	end
end

local function pedFor(serverId)
	if serverId == cache.serverId then
		return cache.ped
	end

	local playerId = GetPlayerFromServerId(serverId)
	if playerId == -1 then return end

	local ped = GetPlayerPed(playerId)
	if ped and ped ~= 0 and DoesEntityExist(ped) then
		return ped
	end
end

local function createWeaponProp(name, meta)
	local item = Items(name)
	local weaponHash = item and item.hash
	if not weaponHash then return end

	RequestWeaponAsset(weaponHash, 31, 0)

	local loaded = lib.waitFor(function()
		return HasWeaponAssetLoaded(weaponHash) or nil
	end, nil, 2000)

	if not loaded then return end

	local coords = GetEntityCoords(cache.ped)
	-- Local object: every client draws their own copy (components sync correctly this way)
	local entity = CreateWeaponObject(weaponHash, 1, coords.x, coords.y, coords.z, true, 1.0, 0)

	if not entity or entity == 0 then
		RemoveWeaponAsset(weaponHash)
		return
	end

	SetEntityAsMissionEntity(entity, true, false)
	applyWeaponComponents(entity, weaponHash, meta, name)
	RemoveWeaponAsset(weaponHash)

	return entity
end

local function createObjectProp(name, cfg)
	local model = cfg.model
	if type(model) == 'string' then model = joaat(model) end
	if not model then
		local item = Items(name)
		model = item and item.hash or joaat(name)
	end

	if not lib.requestModel(model, 2000) then return end

	local coords = GetEntityCoords(cache.ped)
	local entity = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
	SetModelAsNoLongerNeeded(model)

	return entity
end

-- `pos`: where on the bone it went (its own spot, or one of cfg.spots when that was taken)
local function attachToPed(entity, ped, cfg, pos)
	pos = pos or cfg.pos or vec3(0.0, 0.0, 0.0)
	local rot = cfg.rot or vec3(0.0, 0.0, 0.0)
	local bone = resolveBone(ped, cfg.bone or 24818)

	SetEntityVisible(entity, true, false)
	AttachEntityToEntity(entity, ped, bone, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 2, true)
end

-- `held`: for the local player, the weapon ox_inventory:currentWeapon just carried (false
-- for none). That event fires before the inventory's own record changes, so asking
-- getCurrentWeapon then still gave the gun just put away, and it stayed off the body.
local function isHoldingWeapon(serverId, ped, name, held)
	local item = Items(name)
	local hash = item and item.hash
	if not hash or not ped then return false end

	if serverId == cache.serverId then
		local equipped = held
		if equipped == nil then equipped = exports.ox_inventory:getCurrentWeapon() end
		if not equipped or equipped.name ~= name then return false end

		if cache.vehicle then
			return GetSelectedPedWeapon(ped) == hash
		end

		return true
	end

	return GetSelectedPedWeapon(ped) == hash
end

-- Vehicle classes you sit on, not in: motorcycles, cycles, boats. hideInVehicle doesn't
-- hide anything on them.
local OPEN_VEHICLES = { [8] = true, [13] = true, [14] = true }

local function shouldHide(serverId, ped, name, cfg, held)
	local isWeapon = name:sub(1, 7) == 'WEAPON_'
	local hideWhenEquipped = cfg.hideWhenEquipped
	if hideWhenEquipped == nil then hideWhenEquipped = isWeapon end

	if hideWhenEquipped and isHoldingWeapon(serverId, ped, name, held) then return true end

	if cfg.hideInVehicle then
		local vehicle = serverId == cache.serverId and cache.vehicle or GetVehiclePedIsIn(ped, false)
		if vehicle and vehicle ~= 0 and not OPEN_VEHICLES[GetVehicleClass(vehicle)] then
			return true
		end
	end

	return false
end

-- Two things on one bone within this of each other are in the same spot (guns 7 cm apart
-- sit in each other; spots 11 cm apart don't)
local SPOT_RADIUS = 0.1

local function spotTaken(taken, bone, pos)
	for i = 1, #taken do
		if taken[i].bone == bone and #(taken[i].pos - pos) < SPOT_RADIUS then return true end
	end
	return false
end

-- Where each shown item goes, in inventory slot order (so every client agrees): its own
-- spot, else the first free one of cfg.spots; with none free it isn't shown.
local function placeAll(names, payload)
	table.sort(names, function(a, b)
		local sa, sb = payload[a].slot or 999, payload[b].slot or 999
		if sa ~= sb then return sa < sb end
		return a < b
	end)

	local taken, places = {}, {}

	for i = 1, #names do
		local cfg = Config[names[i]]
		local bone = cfg.bone or 24818
		local pos = cfg.pos or vec3(0.0, 0.0, 0.0)

		if spotTaken(taken, bone, pos) then
			pos = nil
			for _, spot in ipairs(cfg.spots or {}) do
				if not spotTaken(taken, bone, spot) then pos = spot break end
			end
		end

		if pos then
			taken[#taken + 1] = { bone = bone, pos = pos }
			places[names[i]] = pos
		end
	end

	return places
end

local function ensureAttachment(serverId, ped, name, cfg, meta, pos)
	attached[serverId] = attached[serverId] or {}
	local byPlayer = attached[serverId]
	local signature = componentSignature(meta)
	local current = byPlayer[name]

	-- Re-pin surviving props (GTA often detaches them on vehicle enter/exit), and move one
	-- whose spot changed (another item freed or took its spot)
	if current and current.signature == signature and current.entity and DoesEntityExist(current.entity) then
		if current.pos ~= pos or not IsEntityAttachedToEntity(current.entity, ped) then
			attachToPed(current.entity, ped, cfg, pos)
			current.pos = pos
		end
		return
	end

	if current and current.pending == signature then
		return
	end

	deleteAttachment(serverId, name)
	attached[serverId] = attached[serverId] or {}
	attached[serverId][name] = { pending = signature, signature = signature }

	local isWeapon = name:sub(1, 7) == 'WEAPON_'
	local entity = isWeapon and createWeaponProp(name, meta) or createObjectProp(name, cfg)

	if not attached[serverId] or not attached[serverId][name] or attached[serverId][name].pending ~= signature then
		if entity then Utils.DeleteEntity(entity) end
		return
	end

	if not entity then
		attached[serverId][name] = nil
		return
	end

	-- Ped may have streamed out while the model loaded
	ped = pedFor(serverId)
	if not ped then
		Utils.DeleteEntity(entity)
		attached[serverId][name] = nil
		return
	end

	SetEntityCollision(entity, false, false)
	SetEntityCompletelyDisableCollision(entity, true, false)
	SetCanClimbOnEntity(entity, false)
	attachToPed(entity, ped, cfg, pos)

	attached[serverId][name] = { entity = entity, signature = signature, pos = pos }
end

---@param held? table | false the local player's weapon from ox_inventory:currentWeapon (false: none)
local function refreshPlayer(serverId, payload, held)
	local ped = pedFor(serverId)
	if not ped then
		clearPlayer(serverId)
		return
	end

	payload = payload or {}
	local owned, shown = {}, {}

	for name in pairs(payload) do
		local cfg = Config[name]
		if cfg then
			owned[name] = true
			if not shouldHide(serverId, ped, name, cfg, held) then shown[#shown + 1] = name end
		end
	end

	local places = placeAll(shown, payload)

	for name in pairs(owned) do
		if places[name] then
			ensureAttachment(serverId, ped, name, Config[name], payload[name], places[name])
		else
			deleteAttachment(serverId, name)
		end
	end

	local byPlayer = attached[serverId]
	if byPlayer then
		for name in pairs(byPlayer) do
			if not owned[name] then
				deleteAttachment(serverId, name)
			end
		end
	end
end

local function refreshAll()
	-- Local player always; remotes from state bags already tracked
	refreshPlayer(cache.serverId, LocalPlayer.state.ox_attachments)

	for serverId in pairs(attached) do
		if serverId ~= cache.serverId then
			local player = Player(serverId)
			refreshPlayer(serverId, player and player.state and player.state.ox_attachments)
		end
	end
end

AddStateBagChangeHandler('ox_attachments', nil, function(bagName, _, value)
	local serverId = tonumber(bagName:match('player:(%d+)'))
	if not serverId then return end

	if value == nil then
		clearPlayer(serverId)
		return
	end

	refreshPlayer(serverId, value)
end)

AddEventHandler('ox_inventory:currentWeapon', function(weapon)
	refreshPlayer(cache.serverId, LocalPlayer.state.ox_attachments, weapon or false)
end)

lib.onCache('ped', function()
	clearPlayer(cache.serverId)
	refreshPlayer(cache.serverId, LocalPlayer.state.ox_attachments)
end)

-- Seat changes strip attached objects; refresh again after GTA finishes
lib.onCache('vehicle', function()
	refreshPlayer(cache.serverId, LocalPlayer.state.ox_attachments)
	SetTimeout(250, function()
		refreshPlayer(cache.serverId, LocalPlayer.state.ox_attachments)
	end)
end)

-- Keep remote props pinned / hidden when they draw weapons or change seats
CreateThread(function()
	while true do
		Wait(500)

		-- The local player every time, also with nothing on: re-pin props GTA detached, and
		-- put back anything hidden while a weapon was in hand
		refreshPlayer(cache.serverId, LocalPlayer.state.ox_attachments)

		for serverId in pairs(attached) do
			if serverId ~= cache.serverId then
				local player = Player(serverId)
				refreshPlayer(serverId, player and player.state and player.state.ox_attachments)
			end
		end

		-- Catch remotes that gained attachments while we had none tracked
		for _, playerId in ipairs(GetActivePlayers()) do
			local serverId = GetPlayerServerId(playerId)
			if serverId ~= cache.serverId and not attached[serverId] then
				local player = Player(serverId)
				local payload = player and player.state and player.state.ox_attachments
				if payload and next(payload) then
					refreshPlayer(serverId, payload)
				end
			end
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= shared.resource then return end

	for serverId in pairs(attached) do
		clearPlayer(serverId)
	end
end)

return { refresh = refreshAll }
