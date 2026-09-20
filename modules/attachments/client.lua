if not lib then return end

local Utils = require 'modules.utils.client'
local Items = require 'modules.items.client'
local attachments = lib.load('data.attachments') or {}

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

local function componentSignature(slot)
	local meta = slot and slot.metadata or {}
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
local function applyWeaponComponents(entity, weaponHash, slot)
	local meta = slot and slot.metadata
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
		local item = Items(slot.name)
		local modelName = item and item.model or slot.name
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

local function deleteAttachment(name)
	local data = attached[name]
	if not data then return end

	if data.entity then
		Utils.DeleteEntity(data.entity)
	end

	attached[name] = nil
end

local function createWeaponProp(name, cfg, slot)
	local item = Items(name)
	local weaponHash = item and item.hash
	if not weaponHash then return end

	RequestWeaponAsset(weaponHash, 31, 0)

	local loaded = lib.waitFor(function()
		return HasWeaponAssetLoaded(weaponHash) or nil
	end, nil, 2000)

	if not loaded then return end

	local coords = GetEntityCoords(cache.ped)
	-- true = default mag so empty weapons still look loaded
	local entity = CreateWeaponObject(weaponHash, 1, coords.x, coords.y, coords.z, true, 1.0, 0)

	if not entity or entity == 0 then
		RemoveWeaponAsset(weaponHash)
		return
	end

	SetEntityAsMissionEntity(entity, true, false)
	applyWeaponComponents(entity, weaponHash, slot)
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

local function attachToPed(entity, cfg)
	local pos = cfg.pos or vec3(0.0, 0.0, 0.0)
	local rot = cfg.rot or vec3(0.0, 0.0, 0.0)
	local bone = resolveBone(cache.ped, cfg.bone or 24818)

	SetEntityVisible(entity, true, false)
	AttachEntityToEntity(entity, cache.ped, bone, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 2, true)
end

local function ensureAttachment(name, cfg, slot)
	local signature = componentSignature(slot)
	local current = attached[name]

	-- Re-pin surviving props; GTA often detaches them on vehicle enter/exit
	if current and current.signature == signature and current.entity and DoesEntityExist(current.entity) then
		if not IsEntityAttachedToEntity(current.entity, cache.ped) then
			attachToPed(current.entity, cfg)
		end
		return
	end

	-- Already spawning this exact suppressor/mag combo
	if current and current.pending == signature then
		return
	end

	deleteAttachment(name)
	attached[name] = { pending = signature, signature = signature }

	local isWeapon = name:sub(1, 7) == 'WEAPON_'
	local entity = isWeapon and createWeaponProp(name, cfg, slot) or createObjectProp(name, cfg)

	-- A later refresh may have cancelled this spawn while we waited for the model
	if not attached[name] or attached[name].pending ~= signature then
		if entity then Utils.DeleteEntity(entity) end
		return
	end

	if not entity then
		attached[name] = nil
		return
	end

	SetEntityCollision(entity, false, false)
	SetEntityCompletelyDisableCollision(entity, true, false)
	SetCanClimbOnEntity(entity, false)
	attachToPed(entity, cfg)

	attached[name] = { entity = entity, signature = signature }
end

-- Hide only when the gun is actually in-hand. Stored/in-vehicle weapons stay on the body.
local function isHoldingWeapon(name, equipped)
	if not equipped or equipped.name ~= name then return false end

	local hash = equipped.hash
	if cache.vehicle and hash then
		return GetSelectedPedWeapon(cache.ped) == hash
	end

	return true
end

local function shouldHide(name, cfg, equipped)
	local isWeapon = name:sub(1, 7) == 'WEAPON_'
	local hideWhenEquipped = cfg.hideWhenEquipped
	if hideWhenEquipped == nil then hideWhenEquipped = isWeapon end

	if hideWhenEquipped and isHoldingWeapon(name, equipped) then return true end
	if cfg.hideInVehicle and cache.vehicle then return true end

	return false
end

-- Drop handles GTA deleted during seat changes so the next spawn is clean
local function pruneMissing()
	for name, data in pairs(attached) do
		if data.entity and not DoesEntityExist(data.entity) then
			attached[name] = nil
		end
	end
end

-- fromWeaponEvent: Equip/Disarm fire this before getCurrentWeapon() is assigned
local function refresh(equipped, fromWeaponEvent)
	pruneMissing()

	local inventory = PlayerData and PlayerData.inventory
	if not fromWeaponEvent then
		equipped = exports.ox_inventory:getCurrentWeapon()
	end

	local owned = {}

	if inventory then
		for _, slot in pairs(inventory) do
			local name = slot and slot.name
			local cfg = name and attachments[name]
			if cfg and not owned[name] then
				owned[name] = { cfg = cfg, slot = slot }
			end
		end
	end

	for name, data in pairs(owned) do
		if shouldHide(name, data.cfg, equipped) then
			deleteAttachment(name)
		else
			ensureAttachment(name, data.cfg, data.slot)
		end
	end

	for name in pairs(attached) do
		if not owned[name] then
			deleteAttachment(name)
		end
	end
end

AddEventHandler('ox_inventory:updateInventory', function()
	refresh()
end)

AddEventHandler('ox_inventory:currentWeapon', function(weapon)
	refresh(weapon, true)
end)

lib.onCache('ped', function()
	for name in pairs(attached) do
		deleteAttachment(name)
	end
	refresh()
end)

-- Seat changes strip attached objects; refresh again after GTA finishes
lib.onCache('vehicle', function()
	refresh()
	SetTimeout(250, refresh)
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= shared.resource then return end

	for name in pairs(attached) do
		deleteAttachment(name)
	end
end)

return { refresh = refresh }
