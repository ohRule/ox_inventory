if not lib then return end

-- Handshake with NUI immediately so the UI page can load while the rest of this file runs.
RegisterNUICallback('uiLoaded', function(_, cb)
	client.uiLoaded = true
	cb(1)
end)

require 'modules.bridge.client'
require 'modules.interface.client'

local Utils = require 'modules.utils.client'
local Weapon = require 'modules.weapon.client'
require 'modules.attachments.client'
require 'modules.dragcraft.client'
local currentWeapon
local storedWeaponOnVehicleEntry
local isReEquippingWeapon = false
local manuallyHolsteredInVehicle = false

local function weaponUsableInVehicle(hash)
	local vehicle = GetVehiclePedIsIn(cache.ped, false)
	if vehicle == 0 then return true end

	local class = GetVehicleClass(vehicle)
	if class == 8 or class == 13 then return true end
	if class == 15 and cache.seat and cache.seat > 0 then return true end

	local group = GetWeapontypeGroup(hash)
	return group == `GROUP_PISTOL` or group == `GROUP_STUNGUN`
end

exports('getCurrentWeapon', function()
	return currentWeapon
end)

RegisterNetEvent('ox_inventory:disarm', function(noAnim)
	currentWeapon = Weapon.Disarm(currentWeapon, noAnim)
end)

RegisterNetEvent('ox_inventory:clearWeapons', function()
	Weapon.ClearAll(currentWeapon)
end)

local StashTarget

exports('setStashTarget', function(id, owner)
	StashTarget = id and {id=id, owner=owner}
end)

---@type boolean | number
local invBusy = true

---@type boolean?
local invOpen = false
local IsPedCuffed = IsPedCuffed
local playerPed = cache.ped

lib.onCache('ped', function(ped)
	playerPed = ped
	Utils.WeaponWheel()
end)

client.player:set('invBusy', true)
client.player:set('invHotkeys', false)
client.player:set('canUseWeapons', false)

local function canOpenInventory()
    if not PlayerData.loaded then
        return shared.info('cannot open inventory', '(player inventory has not loaded)')
    end

    -- Wearables uses an empty pause-menu overlay for the ped preview
    if invOpen == nil then return end
    if IsPauseMenuActive() and not client.wearablesPreview then return end

    if invBusy or (currentWeapon?.timer or 0) > 0 then
        return shared.info('cannot open inventory', '(is busy)')
    end

    if PlayerData.dead or IsPedFatallyInjured(playerPed) then
        return shared.info('cannot open inventory', '(fatal injury)')
    end

    if PlayerData.cuffed or IsPedCuffed(playerPed) then
        return shared.info('cannot open inventory', '(cuffed)')
    end

    return true
end

---@param ped number
---@return boolean
local function canOpenTarget(ped)
	return IsPedFatallyInjured(ped)
	or IsEntityPlayingAnim(ped, 'dead', 'dead_a', 3)
	or IsPedCuffed(ped)
	or IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3)
	or IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3)
	or IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_enter', 3)
	or IsEntityPlayingAnim(ped, 'random@mugging3', 'handsup_standing_base', 3)
end

---@class OpenInventory
---@field id string | integer
---@field label string
---@field type string
---@field slots integer
---@field weight integer
---@field maxWeight integer
---@field coords? vector3
---@field distance? integer
---@field instance? string | number
---@field [string] unknown
local defaultInventory = {
	type = 'newdrop',
	slots = shared.dropslots,
	weight = 0,
	maxWeight = shared.dropweight,
	items = {}
}

local currentInventory = defaultInventory

local function closeTrunk()
	if currentInventory.type == 'trunk' then
		local coords = GetEntityCoords(playerPed, true)
		---@todo animation for vans?
		Utils.PlayAnimAdvanced(0, 'anim@heists@fleeca_bank@scope_out@return_case', 'trevor_action', coords.x, coords.y, coords.z, 0.0, 0.0, GetEntityHeading(playerPed), 2.0, 2.0, 1000, 49, 0.25)

		CreateThread(function()
			local entity = currentInventory.entity
			local door = currentInventory.door
			Wait(900)

			if type(door) == 'table' then
				for i = 1, #door do
					SetVehicleDoorShut(entity, door[i], false)
				end
			else
				SetVehicleDoorShut(entity, door, false)
			end
		end)
	end
end

local CraftingBenches = require 'modules.crafting.client'
require 'modules.recycler.client'
require 'modules.furnace.client'
require 'modules.loot.client'
require 'modules.ammobox.client'
require 'modules.magload.client'
require 'modules.loadout.client'
local QuickCraft = require 'modules.quickcraft.client'
local Wearables = require 'modules.wearables.client'
local Vehicles = lib.load('data.vehicles')
local Inventory = require 'modules.inventory.client'

-- Hotbar keys bind to items without moving them out of the inventory
local HOTBAR_SIZE = 6
local hotbarBinds = {}
local hotbarReady = false

local function getHotbarPayload()
	local payload = {}

	for i = 1, HOTBAR_SIZE do
		payload[i] = hotbarBinds[i] or false
	end

	return payload
end

local function applyHotbarBinds(decoded)
	hotbarBinds = {}
	if type(decoded) ~= 'table' then return false end

	local hasBind = false

	for i = 1, HOTBAR_SIZE do
		local bind = decoded[i] or decoded[tostring(i)]
		if type(bind) == 'table' and type(bind.name) == 'string' then
			hotbarBinds[i] = {
				slot = tonumber(bind.slot),
				name = bind.name,
				serial = bind.serial
			}
			hasBind = true
		end
	end

	return hasBind
end

-- Persist to the character's DB row (server) — source of truth across PCs / characters
local function saveHotbarBinds()
	if not hotbarReady then return end
	TriggerServerEvent('ox_inventory:saveHotbar', getHotbarPayload())
end

-- Apply server binds; one-time migrate leftover client KVP if this character has none yet
local function loadHotbarFromServer(serverBinds)
	-- nil = no DB row yet; table (even empty) = character already has saved hotbar data
	if serverBinds ~= nil then
		applyHotbarBinds(serverBinds)
		DeleteResourceKvp('ox_inventory:hotbarBinds')
	else
		local raw = GetResourceKvpString('ox_inventory:hotbarBinds')
		if raw then
			local decoded = json.decode(raw)
			if applyHotbarBinds(decoded) then
				TriggerServerEvent('ox_inventory:migrateHotbar', getHotbarPayload())
			end
			DeleteResourceKvp('ox_inventory:hotbarBinds')
		else
			hotbarBinds = {}
		end
	end

	hotbarReady = true
	SendNUIMessage({ action = 'setupHotbar', data = getHotbarPayload() })
end

-- Clear binds on logout so the next character doesn't briefly show the previous set
do
	local _onLogout = client.onLogout
	function client.onLogout(...)
		hotbarBinds = {}
		hotbarReady = false
		SendNUIMessage({ action = 'setupHotbar', data = getHotbarPayload() })
		return _onLogout(...)
	end
end

-- HUD hotbar is visible unless the player has hidden it (unset KVP defaults to on)
local hotbarHudVisible = GetResourceKvpString('ox_inventory:hotbarHud') ~= '0'

local function setHotbarHudVisible(visible)
	hotbarHudVisible = visible and true or false
	SetResourceKvp('ox_inventory:hotbarHud', hotbarHudVisible and '1' or '0')
	SendNUIMessage({ action = 'setHotbarHud', data = hotbarHudVisible })
end

---@param index number
---@return number?
local function resolveHotbarSlot(index)
	local bind = hotbarBinds[index]
	if not bind or not bind.name then return end

	local inventory = PlayerData.inventory
	if not inventory then return end

	local slotItem = bind.slot and inventory[bind.slot]
	if slotItem and slotItem.name == bind.name and (not bind.serial or slotItem.metadata?.serial == bind.serial) then
		return bind.slot
	end

	for slot, item in pairs(inventory) do
		if item and item.name == bind.name and (not bind.serial or item.metadata?.serial == bind.serial) then
			bind.slot = slot
			return slot
		end
	end
end

---@param inv string?
---@param data any?
---@return boolean?
function client.openInventory(inv, data)
	if invOpen == nil then return end

	if invOpen then
		if not inv and currentInventory.type == 'newdrop' then
			return client.closeInventory()
		end

		if IsNuiFocused() then
			if inv == 'container' and currentInventory.id == PlayerData.inventory[data].metadata.container then
				return client.closeInventory()
			end

			if currentInventory.type == 'drop' and (not data or currentInventory.id == (type(data) == 'table' and data.id or data)) then
				return client.closeInventory()
			end

			if inv ~= 'drop' and inv ~= 'container' then
				if (data?.id or data) == currentInventory.id then
					-- Triggering exports.ox_inventory:openInventory('stash', 'mystash') twice in rapid succession is weird behaviour
					return warn(("script tried to open inventory, but it is already open\n%s"):format(Citizen.InvokeNative(`FORMAT_STACK_TRACE` & 0xFFFFFFFF, nil, 0, Citizen.ResultAsString())))
				else
					return client.closeInventory()
				end
			end
		end
	elseif IsNuiFocused() then
		-- If triggering from another nui, may need to wait for focus to end.
		Wait(100)

        -- People still complain about this being an "error" and ask "how fix" despite being a warning
        -- for people with above room-temperature iqs to look into resource conflicts on their own.
		-- if IsNuiFocused() then
		-- 	warn('other scripts have nui focus and may cause issues (e.g. disable focus, prevent input, overlap inventory window)')
		-- end
	end

	if inv == 'dumpster' and cache.vehicle then
		return lib.notify({ id = 'inventory_right_access', type = 'error', description = locale('inventory_right_access') })
	end

	if not canOpenInventory() then
        return lib.notify({ id = 'inventory_player_access', type = 'error', description = locale('inventory_player_access') })
    end

    local left, right, accessError

    if inv == 'player' and data ~= cache.serverId then
        local targetId, targetPed, serverId

        if not data then
            targetId, targetPed = Utils.GetClosestPlayer()
            serverId = targetId and GetPlayerServerId(targetId)
            data = serverId
        else
            serverId = type(data) == 'table' and data.id or data
            targetId = serverId and GetPlayerFromServerId(serverId)
            targetPed = targetId and GetPlayerPed(targetId)
        end

        if serverId == cache.serverId then return end

        local targetCoords = targetPed and GetEntityCoords(targetPed)

        if not targetCoords or #(targetCoords - GetEntityCoords(playerPed)) > 1.8 or (not client.hasGroup(shared.police) and not Player(serverId).state.canSteal) then
            return lib.notify({ id = 'inventory_right_access', type = 'error', description = locale('inventory_right_access') })
        end
    end

    if inv == 'shop' and invOpen == false then
        if cache.vehicle then
            return lib.notify({ id = 'cannot_perform', type = 'error', description = locale('cannot_perform') })
        end

        left, right, accessError = lib.callback.await('ox_inventory:openShop', 200, data)
    elseif inv == 'crafting' then
        if cache.vehicle then
            return lib.notify({ id = 'cannot_perform', type = 'error', description = locale('cannot_perform') })
        end

        left, right, accessError = lib.callback.await('ox_inventory:openCraftingBench', 200, data.id, data.index)

        if left then
            right = CraftingBenches[data.id]

            if not right?.items then return end

            local coords, distance

            if right.locations and right.locations[data.index] then
                local loc = right.locations[data.index]
                coords = (type(loc) == 'table' and loc.coords) or loc
                distance = 2
            elseif not right.zones and not right.points then
                coords = GetEntityCoords(cache.ped)
                distance = 2
            else
                coords = shared.target and right.zones and right.zones[data.index].coords or right.points and right.points[data.index]
                distance = coords and shared.target and right.zones[data.index].distance or 2
            end

            local benchData = lib.callback.await('ox_inventory:getCraftingBenchData', 200, data.id, data.index)

            right = {
                type = 'crafting',
                id = data.id,
                label = (benchData and benchData.label) or right.label or locale('crafting_bench'),
                index = data.index,
                slots = (benchData and benchData.slots) or right.slots,
                items = (benchData and benchData.items) or right.items,
                coords = coords,
                distance = distance,
                techTree = benchData and benchData.techTree or false,
                unlockScrapItem = benchData and benchData.unlockScrapItem,
                treeRootSlots = benchData and benchData.treeRootSlots,
                treeChildren = benchData and benchData.treeChildren,
            }
        end
    elseif inv == 'recycler' or inv == 'lootprop' or inv == 'research' or inv == 'furnace' then
        if cache.vehicle then
            return lib.notify({ id = 'cannot_perform', type = 'error', description = locale('cannot_perform') })
        end

        left, right, accessError = lib.callback.await('ox_inventory:openInventory', false, inv, data)
    elseif inv == 'armoury' then
        left, right, accessError = lib.callback.await('ox_inventory:openInventory', false, inv, data)
    elseif invOpen ~= nil then
        if inv == 'policeevidence' then
            if not data then
                local input = lib.inputDialog(locale('police_evidence'), {
                    { label = locale('locker_number'), type = 'number', required = true, icon = 'calculator' }
                }) --[[@as number[]? ]]

                if not input then return end

                data = input[1]
            end
        end

        left, right, accessError = lib.callback.await('ox_inventory:openInventory', false, inv, data)
    end

    if accessError then
        return lib.notify({ id = accessError, type = 'error', description = locale(accessError) })
    end

    -- Stash does not exist
    if not left then
        if left == false then return false end

        if invOpen == false then
            return lib.notify({ id = 'inventory_right_access', type = 'error', description = locale('inventory_right_access') })
        end

        if invOpen then return client.closeInventory() end
    end


    if not cache.vehicle then
        if inv == 'player' then
            Utils.PlayAnim(0, 'mp_common', 'givetake1_a', 8.0, 1.0, 2000, 50, 0.0, 0, 0, 0)
        elseif inv ~= 'trunk' then
            Utils.PlayAnim(0, 'pickup_object', 'putdown_low', 5.0, 1.5, 1000, 48, 0.0, 0, 0, 0)
        end
    end

	client.player:set('invOpen', true)

    SetInterval(client.interval, 100)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    closeTrunk()

    if client.screenblur then Utils.blurIn() end

    currentInventory = right or defaultInventory
    left.items = PlayerData.inventory
    left.groups = PlayerData.groups

    SendNUIMessage({
        action = 'setupInventory',
        data = {
            leftInventory = left,
            rightInventory = currentInventory
        }
    })

    if inv and not currentInventory.coords and inv ~= 'container' and inv ~= 'glovebox' then
        currentInventory.coords = GetEntityCoords(playerPed)
    end

    if inv == 'trunk' then
        SetTimeout(200, function()
            ---@todo animation for vans?
            Utils.PlayAnim(0, 'anim@heists@prison_heiststation@cop_reactions', 'cop_b_idle', 3.0, 3.0, -1, 49, 0.0, 0, 0, 0)

            local entity = data.entity or NetworkGetEntityFromNetworkId(data.netid)
            currentInventory.entity = entity
            currentInventory.door = data.door

            if not currentInventory.door then
                local vehicleHash = GetEntityModel(entity)
                local vehicleClass = GetVehicleClass(entity)
                currentInventory.door = vehicleClass == 12 and { 2, 3 } or Vehicles.Storage[vehicleHash] and 4 or 5
            end

            while currentInventory.entity == entity and invOpen and DoesEntityExist(entity) and Inventory.CanAccessTrunk(entity) do
                Wait(100)
            end

            if invOpen then client.closeInventory() end
        end)
    end

    return true
end

RegisterNetEvent('ox_inventory:openInventory', client.openInventory)
exports('openInventory', client.openInventory)

RegisterNetEvent('ox_inventory:forceOpenInventory', function(left, right)
	if source == '' then return end

	client.player:set('invOpen', true)

	SetInterval(client.interval, 100)
	SetNuiFocus(true, true)
	SetNuiFocusKeepInput(true)
	closeTrunk()

	if client.screenblur then Utils.blurIn() end

	currentInventory = right or defaultInventory
	currentInventory.ignoreSecurityChecks = true
	left.items = PlayerData.inventory
	left.groups = PlayerData.groups

	SendNUIMessage({
		action = 'setupInventory',
		data = {
			leftInventory = left,
			rightInventory = currentInventory
		}
	})
end)

local Animations = lib.load('data.animations')
local Items = require 'modules.items.client'
local usingItem = false

---@param data { name: string, label: string, count: number, slot: number, metadata: table<string, any>, weight: number }
lib.callback.register('ox_inventory:usingItem', function(data, noAnim)
	local item = Items[data.name]

	if item and usingItem then
		if not item.client then return true end
		---@cast item +OxClientProps
		item = item.client

		if type(item.anim) == 'string' then
			item.anim = Animations.anim[item.anim]
		end

		if item.prop then
			if item.prop[1] then
				for i = 1, #item.prop do
					if type(item.prop) == 'string' then
						item.prop = Animations.prop[item.prop[i]]
					end
				end
			elseif type(item.prop) == 'string' then
				item.prop = Animations.prop[item.prop]
			end
		end

		if not item.disable then
			item.disable = { combat = true }
		elseif item.disable.combat == nil then
			-- Backwards compatibility; you probably don't want people shooting while eating and bandaging anyway
			item.disable.combat = true
		end

		local success = (not item.usetime or noAnim or lib.progressBar({
			duration = item.usetime,
			label = item.label or locale('using', data.metadata.label or data.label),
			useWhileDead = item.useWhileDead,
			canCancel = item.cancel,
			disable = item.disable,
			anim = item.anim or item.scenario,
			prop = item.prop --[[@as ProgressProps]]
		})) and not PlayerData.dead

		if success then
			if item.notification then
				lib.notify({ description = item.notification })
			end

			if item.status then
				if client.setPlayerStatus then
					client.setPlayerStatus(item.status)
				end
			end

			return true
		end
	end
end)

local function canUseItem(isAmmo)
	local ped = cache.ped

	return not usingItem
    and (not isAmmo or currentWeapon)
	and PlayerData.loaded
	and not PlayerData.dead
	and not invBusy
	and not lib.progressActive()
	and not IsPedRagdoll(ped)
	and not IsPedFalling(ped)
    and not IsPedShooting(playerPed)
end

---@param data table
---@param cb fun(response: SlotWithItem | false)?
---@param noAnim? boolean
local function useItem(data, cb, noAnim)
	local slotData, result = PlayerData.inventory[data.slot]

	if not slotData or not canUseItem(data.ammo and true) then
        if currentWeapon then
            return lib.notify({ id = 'cannot_perform', type = 'error', description = locale('cannot_perform') })
        end

        return
    end

	if currentWeapon and currentWeapon.timer ~= 0 then
        if not currentWeapon.timer or currentWeapon.timer - GetGameTimer() > 100 then return end

        DisablePlayerFiring(cache.playerId, true)
    end

    if invOpen and data.close then client.closeInventory() end

    usingItem = true
    ---@type boolean?
    result = lib.callback.await('ox_inventory:useItem', 200, data.name, data.slot, slotData.metadata, noAnim)

	if result and cb then
		local success, response = pcall(cb, result and slotData)

		if not success and response then
			warn(('^1An error occurred while calling item "%s" callback!\n^1SCRIPT ERROR: %s^0'):format(slotData.name, response))
		end
	end

    if result then
        TriggerEvent('ox_inventory:usedItem', slotData.name, slotData.slot, next(slotData.metadata) and slotData.metadata)
    end

	Wait(500)
    usingItem = false
end

AddEventHandler('ox_inventory:usedItem', function(name, slot, metadata)
    TriggerServerEvent('ox_inventory:usedItemInternal', slot)
end)

-- Ignore the disarm event that happens while swapping to another weapon
local skipHotbarUnequip = false

local function sendHotbarEquipped(ref)
	SendNUIMessage({
		action = 'hotbarEquipped',
		data = (ref and ref.name) and {
			slot = ref.slot,
			name = ref.name,
			serial = ref.serial or (ref.metadata and ref.metadata.serial) or nil,
		} or false
	})
end

AddEventHandler('ox_inventory:currentWeapon', function(weapon)
	-- Keep the hotbar lit when GTA disarms us for a vehicle; we re-equip on exit
	if not weapon and skipHotbarUnequip then return end
	if not weapon and storedWeaponOnVehicleEntry and GetVehiclePedIsIn(cache.ped, false) ~= 0 then return end

	sendHotbarEquipped(weapon)
end)

AddEventHandler('ox_inventory:item', useItem)
exports('useItem', useItem)

---@param slot number
---@return boolean?
local function useSlot(slot, noAnim)
	local item = PlayerData.inventory[slot]
	if not item then return end

	local data = Items[item.name]
	if not data then return end

	if canUseItem(data.ammo and true) then
		if data.component and not currentWeapon then
			return lib.notify({ id = 'weapon_hand_required', type = 'error', description = locale('weapon_hand_required') })
		end

		local durability = item.metadata.durability --[[@as number?]]
		local consume = data.consume --[[@as number?]]
		local label = item.metadata.label or item.label --[[@as string]]

		-- Naive durability check to get an early exit (skipped when durability system is off)
		-- People often don't call the 'useItem' export and then complain about "broken" items being usable
		-- This won't work with degradation since we need access to os.time on the server
		if shared.durability and durability and durability <= 100 and consume then
			if durability <= 0 then
				return lib.notify({ type = 'error', description = locale('no_durability', label) })
			elseif consume ~= 0 and consume < 1 and durability < consume * 100 then
				return lib.notify({ type = 'error', description = locale('not_enough_durability', label) })
			end
		end

		data.slot = slot

		if item.metadata.container then
			return client.openInventory('container', item.slot)
		elseif data.client then
			if invOpen and data.close then client.closeInventory() end

			if data.export then
				return data.export(data, {name = item.name, slot = item.slot, metadata = item.metadata})
			elseif data.client.event then -- re-add it, so I don't need to deal with morons taking screenshots of errors when using trigger event
				return TriggerEvent(data.client.event, data, {name = item.name, slot = item.slot, metadata = item.metadata})
			end
		end

		if data.effect then
			data:effect({name = item.name, slot = item.slot, metadata = item.metadata})
		elseif data.weapon then
			if EnableWeaponWheel or not client.player:get('canUseWeapons') then return end

			if IsCinematicCamRendering() then SetCinematicModeActive(false) end

			local inVehicle = GetVehiclePedIsIn(cache.ped, false) ~= 0
			if inVehicle and not currentWeapon and storedWeaponOnVehicleEntry and data.slot == storedWeaponOnVehicleEntry.slot then
				storedWeaponOnVehicleEntry = nil
				manuallyHolsteredInVehicle = true
				if client.weaponnotify then
					Utils.ItemNotify({ item, 'ui_holstered' })
				end
				sendHotbarEquipped(false)
				return
			end

			if inVehicle and not isReEquippingWeapon then
				local equipped = lib.progressBar({
					duration = 3000,
					label = locale('using', item.metadata.label or data.label),
					useWhileDead = false,
					canCancel = true,
					disable = { combat = true },
				})

				if not equipped then
					sendHotbarEquipped(storedWeaponOnVehicleEntry or false)
					return
				end
			end

			if currentWeapon then
                if not currentWeapon.timer or currentWeapon.timer ~= 0 then return end

				local weaponSlot = currentWeapon.slot
				local wasInVehicle = GetVehiclePedIsIn(cache.ped, false) ~= 0

				if weaponSlot == data.slot then
					storedWeaponOnVehicleEntry = nil
					if wasInVehicle then
						manuallyHolsteredInVehicle = true
						if client.weaponnotify then
							Utils.ItemNotify({ currentWeapon, 'ui_holstered' })
						end
					end
				end

				local switching = weaponSlot ~= data.slot
				if switching then skipHotbarUnequip = true end
				currentWeapon = Weapon.Disarm(currentWeapon)
				skipHotbarUnequip = false

				if not switching then return end
			end

			manuallyHolsteredInVehicle = false

			if inVehicle then
				if storedWeaponOnVehicleEntry and storedWeaponOnVehicleEntry.slot ~= data.slot then
					RemoveAllPedWeapons(cache.ped, true)
				end

				storedWeaponOnVehicleEntry = {
					slot = data.slot,
					name = item.name,
					hash = data.hash,
					serial = item.metadata and item.metadata.serial or nil,
				}
				sendHotbarEquipped(storedWeaponOnVehicleEntry)

				-- Rifles/etc can't be held in a car — store them for exit without putting them in-hand
				if not weaponUsableInVehicle(data.hash) then
					if client.weaponnotify then
						Utils.ItemNotify({ item, 'ui_equipped' })
					end
					return
				end
			end

            GiveWeaponToPed(playerPed, data.hash, 0, false, true)
            SetCurrentPedWeapon(playerPed, data.hash, false)

            -- GTA will not report rifles/etc as selected while seated; skip the fail-out so you can still ready a gun in a car
            if not inVehicle and data.hash ~= GetSelectedPedWeapon(playerPed) then
                lib.print.info(('failed to equip %s (cause unknown)'):format(item.name))
				SendNUIMessage({ action = 'hotbarEquipped', data = false })
                return lib.notify({ type = 'error', description = locale('cannot_use', data.label) })
            end

            RemoveWeaponFromPed(cache.ped, data.hash)

			useItem(data, function(result)
				if result then
                    local sleep
					currentWeapon, sleep = Weapon.Equip(item, data, noAnim, isReEquippingWeapon)

					if sleep then Wait(sleep) end
				end
			end, noAnim)

			-- useItem only runs its callback on success; keep the stored/readied bind lit in a vehicle
			if not currentWeapon and not storedWeaponOnVehicleEntry then
				sendHotbarEquipped(false)
			elseif storedWeaponOnVehicleEntry and not currentWeapon then
				sendHotbarEquipped(storedWeaponOnVehicleEntry)
			end
		elseif currentWeapon then
			if data.ammo then
				if EnableWeaponWheel or (shared.durability and currentWeapon.metadata.durability <= 0) then return end

				local weaponItem = Items[currentWeapon.name]
				local useMagazine = weaponItem and (weaponItem.useMagazine or weaponItem.usesMagazine)
				local magazineItem = weaponItem and weaponItem.ammoname
				local isShotgun = currentWeapon.group == `GROUP_SHOTGUN` or (magazineItem and magazineItem:find('shotgun'))

				-- 1 magazine item = full clip; shotguns still load shell-by-shell
				if useMagazine and data.name == magazineItem and not isShotgun then
					useItem(data, function(resp)
						if not resp or resp.name ~= magazineItem then return end

						local clipSize = GetMaxAmmoInClip(playerPed, currentWeapon.hash, true)
						local currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)
						local _, maxAmmo = GetMaxAmmo(playerPed, currentWeapon.hash)

						if maxAmmo < clipSize then clipSize = maxAmmo end
						if currentAmmo >= clipSize then return end

						local newAmmo = clipSize
						AddAmmoToPed(playerPed, currentWeapon.hash, newAmmo - currentAmmo)

						if cache.vehicle then
							if cache.seat > -1 or IsVehicleStopped(cache.vehicle) then
								TaskReloadWeapon(playerPed, true)
							else
								lib.waitFor(function()
									RefillAmmoInstantly(playerPed)
									local _, ammo = GetAmmoInClip(playerPed, currentWeapon.hash)
									return ammo == newAmmo or nil
								end)
							end
						else
							Wait(100)
							MakePedReload(playerPed)

							SetTimeout(100, function()
								while IsPedReloading(playerPed) do
									DisableControlAction(0, 22, true)
									Wait(0)
								end
							end)
						end

						lib.callback.await('ox_inventory:updateWeapon', false, 'loadMagazine', newAmmo, false, currentWeapon.metadata.specialAmmo)
					end)
					return
				end

				if useMagazine and not isShotgun and data.name ~= magazineItem then
					return
				end

				local clipSize = GetMaxAmmoInClip(playerPed, currentWeapon.hash, true)
				local currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)
				local _, maxAmmo = GetMaxAmmo(playerPed, currentWeapon.hash)

				if maxAmmo < clipSize then clipSize = maxAmmo end

				if currentAmmo == clipSize then return end

				useItem(data, function(resp)
					if not resp or resp.name ~= currentWeapon?.ammo then return end

					if currentWeapon.metadata.specialAmmo ~= resp.metadata.type and type(currentWeapon.metadata.specialAmmo) == 'string' then
						local clipComponentKey = ('%s_CLIP'):format(Items[currentWeapon.name].model:gsub('WEAPON_', 'COMPONENT_'))
						local specialClip = ('%s_%s'):format(clipComponentKey, (resp.metadata.type or currentWeapon.metadata.specialAmmo):upper())

						if type(resp.metadata.type) == 'string' then
							if not HasPedGotWeaponComponent(playerPed, currentWeapon.hash, specialClip) then
								if not DoesWeaponTakeWeaponComponent(currentWeapon.hash, specialClip) then
									warn('cannot use clip with this weapon')
									return
								end

								local defaultClip = ('%s_01'):format(clipComponentKey)

								if not HasPedGotWeaponComponent(playerPed, currentWeapon.hash, defaultClip) then
									warn('cannot use clip with currently equipped clip')
									return
								end

								if currentAmmo > 0 then
									warn('cannot mix special ammo with base ammo')
									return
								end

								currentWeapon.metadata.specialAmmo = resp.metadata.type

								GiveWeaponComponentToPed(playerPed, currentWeapon.hash, specialClip)
							end
						elseif HasPedGotWeaponComponent(playerPed, currentWeapon.hash, specialClip) then
							if currentAmmo > 0 then
								warn('cannot mix special ammo with base ammo')
								return
							end

							currentWeapon.metadata.specialAmmo = nil

							RemoveWeaponComponentFromPed(playerPed, currentWeapon.hash, specialClip)
						end
					end

					if maxAmmo > clipSize then
						clipSize = GetMaxAmmoInClip(playerPed, currentWeapon.hash, true)
					end

					currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)
					local missingAmmo = clipSize - currentAmmo
					local addAmmo = resp.count > missingAmmo and missingAmmo or resp.count
					local newAmmo = currentAmmo + addAmmo

					if newAmmo == currentAmmo then return end

                    AddAmmoToPed(playerPed, currentWeapon.hash, addAmmo)

					if cache.vehicle then
						if cache.seat > -1 or IsVehicleStopped(cache.vehicle) then
							TaskReloadWeapon(playerPed, true)
                        else
                            -- This is a hacky solution for forcing ammo to properly load into the
                            -- weapon clip while driving; without it, ammo will be added but won't
                            -- load until the player stops doing anything. i.e. if you keep shooting,
                            -- the weapon will not reload until the clip empties.
                            -- And yes - for some reason RefillAmmoInstantly needs to run in a loop.
                            lib.waitFor(function()
                                RefillAmmoInstantly(playerPed)

                                local _, ammo = GetAmmoInClip(playerPed, currentWeapon.hash)
                                return ammo == newAmmo or nil
                            end)
                        end
					else
						Wait(100)
						MakePedReload(playerPed)

						SetTimeout(100, function()
							while IsPedReloading(playerPed) do
								DisableControlAction(0, 22, true)
								Wait(0)
							end
						end)
					end

					lib.callback.await('ox_inventory:updateWeapon', false, 'load', newAmmo, false, currentWeapon.metadata.specialAmmo)
				end)
			elseif data.component then
				local components = data.client.component

                if not components then return end

				local componentType = data.type
				local weaponComponents = PlayerData.inventory[currentWeapon.slot].metadata.components

				-- Checks if the weapon already has the same component type attached
				for componentIndex = 1, #weaponComponents do
					if componentType == Items[weaponComponents[componentIndex]].type then
						return lib.notify({ id = 'component_slot_occupied', type = 'error', description = locale('component_slot_occupied', componentType) })
					end
				end

				for i = 1, #components do
					local component = components[i]

					if DoesWeaponTakeWeaponComponent(currentWeapon.hash, component) then
						if HasPedGotWeaponComponent(playerPed, currentWeapon.hash, component) then
							lib.notify({ id = 'component_has', type = 'error', description = locale('component_has', label) })
						else
							useItem(data, function(data)
								if data then
									local success = lib.callback.await('ox_inventory:updateWeapon', false, 'component', tostring(data.slot), currentWeapon.slot)

									if success then
										GiveWeaponComponentToPed(playerPed, currentWeapon.hash, component)
										TriggerEvent('ox_inventory:updateWeaponComponent', 'added', component, data.name)
									end
								end
							end)
						end
						return
					end
				end
				lib.notify({ id = 'component_invalid', type = 'error', description = locale('component_invalid', label) })
			elseif data.allowArmed then
				useItem(data)
            else
                return lib.notify({ id = 'cannot_perform', type = 'error', description = locale('cannot_perform') })
			end
		elseif not data.ammo and not data.component then
			useItem(data)
		end
    end
end
exports('useSlot', useSlot)

---@param id number
---@param slot number
local function useButton(id, slot)
	if PlayerData.loaded and not invBusy and not lib.progressActive() then
		local item = PlayerData.inventory[slot]
		if not item then return end

		local data = Items[item.name]
		local buttons = data?.buttons

		if buttons and buttons[id]?.action then
			buttons[id].action(slot)
		end
	end
end

local function openNearbyInventory() client.openInventory('player') end

exports('openNearbyInventory', openNearbyInventory)

local currentInstance
local playerCoords
local Shops = require 'modules.shops.client'

---@todo remove or replace when the bridge module gets restructured
function OnPlayerData(key, val)
	if key ~= 'groups' and key ~= 'ped' and key ~= 'dead' then return end

	if key == 'groups' then
		Inventory.Stashes()
		Inventory.Evidence()
		Shops.refreshShops()
	elseif key == 'dead' and val then
		currentWeapon = Weapon.Disarm(currentWeapon)
		client.closeInventory()
	end

	Utils.WeaponWheel()
end

-- People consistently ignore errors when one of the "modules" failed to load
if not Utils or not Weapon or not Items or not Inventory then return end

local invHotkeys = false

---@type function?
local function registerCommands()
	if client.enablestealcommand then
		RegisterCommand('steal', openNearbyInventory, false)
	end

	local function openGlovebox(vehicle)
		if not IsPedInAnyVehicle(playerPed, false) or not NetworkGetEntityIsNetworked(vehicle) then return end

		if IsEntityDead(vehicle) then return end

		local vehicleHash = GetEntityModel(vehicle)
		local vehicleClass = GetVehicleClass(vehicle)
		local checkVehicle = Vehicles.Storage[vehicleHash]

		-- No storage or no glovebox
		if (checkVehicle == 0 or checkVehicle == 2) or (not Vehicles.glovebox[vehicleClass] and not Vehicles.glovebox.models[vehicleHash]) then return end

		local isOpen = client.openInventory('glovebox', { netid = NetworkGetNetworkIdFromEntity(vehicle) })

		if isOpen then
			currentInventory.entity = vehicle
		end
	end

	local primary = lib.addKeybind({
		name = 'inv',
		description = locale('open_player_inventory'),
		defaultKey = client.keys[1],
		onPressed = function()
			if invOpen then
				return client.closeInventory()
			end

			if cache.vehicle then
				return openGlovebox(cache.vehicle)
			end

			local closest = lib.points.getClosestPoint()

			if closest and closest.currentDistance < 1.2 and (not closest.instance or closest.instance == currentInstance) then
				if closest.inv == 'crafting' then
					return client.openInventory('crafting', { id = closest.id or closest.benchid, index = closest.index })
				elseif closest.inv == 'research' then
					return client.openInventory('research', { id = closest.id or closest.benchid, index = closest.index })
				elseif closest.inv ~= 'license' and closest.inv ~= 'policeevidence' then
					return client.openInventory(closest.inv or 'drop', { id = closest.invId, type = closest.type })
				end
			end

			return client.openInventory()
		end
	})

	lib.addKeybind({
		name = 'inv2',
		description = locale('open_secondary_inventory'),
		defaultKey = client.keys[2],
		onPressed = function(self)
            if primary:getCurrentKey() == self:getCurrentKey() then
                return warn(("secondary inventory keybind '%s' disabled (keybind cannot match primary inventory keybind)"):format(self:getCurrentKey()))
            end

			if invOpen then
				return client.closeInventory()
			end

			if invBusy or not canOpenInventory() then
				return lib.notify({ id = 'inventory_player_access', type = 'error', description = locale('inventory_player_access') })
			end

			if StashTarget then
				return client.openInventory('stash', StashTarget)
			end

			if cache.vehicle then
				return openGlovebox(cache.vehicle)
			end

			local entity, entityType = Utils.Raycast(2|16)

			if not entity then return end

			if not shared.target and entityType == 3 then
				local model = GetEntityModel(entity)

				if Inventory.Dumpsters:includes(model) then
					return Inventory.OpenDumpster(entity)
				end
			end

			if entityType ~= 2 then return end

			Inventory.OpenTrunk(entity)
		end
	})

	lib.addKeybind({
		name = 'reloadweapon',
		description = locale('reload_weapon'),
		defaultKey = 'r',
		onPressed = function(self)
			if not currentWeapon or EnableWeaponWheel or not canUseItem(true) then return end

			if currentWeapon.ammo then
				if not shared.durability or currentWeapon.metadata.durability > 0 then
					local slotId = Inventory.GetSlotIdWithItem(currentWeapon.ammo, { type = currentWeapon.metadata.specialAmmo }, false)

					if slotId then
						useSlot(slotId)
					end
				else
					lib.notify({ id = 'no_durability', type = 'error', description = locale('no_durability', currentWeapon.label) })
				end
			end
		end
	})

	lib.addKeybind({
		name = 'hotbar',
		description = locale('disable_hotbar'),
		defaultKey = client.keys[3],
		onPressed = function()
			if EnableWeaponWheel or not invHotkeys or invOpen or lib.progressActive() then return end
			setHotbarHudVisible(not hotbarHudVisible)
		end
	})

	for i = 1, HOTBAR_SIZE do
		lib.addKeybind({
			name = ('hotkey%s'):format(i),
			description = locale('use_hotbar', i),
			defaultKey = tostring(i),
			onPressed = function()
				if invOpen or EnableWeaponWheel or not invHotkeys or IsNuiFocused() then return end
				local slot = resolveHotbarSlot(i)
				local bound = slot and PlayerData.inventory[slot]
				local hold = bound and Items[bound.name] and Items[bound.name].weapon
				SendNUIMessage({ action = 'hotbarPressed', data = { index = i, hold = hold and true or false } })
				if slot then useSlot(slot) end
			end
		})
	end

	registerCommands = nil
end

function client.closeInventory()
	if not client.interval then return end

	if invOpen then
		invOpen = nil
		SetNuiFocus(false, false)
		SetNuiFocusKeepInput(false)
		Wearables.Stop()
		Utils.blurOut()
		closeTrunk()
		SendNUIMessage({ action = 'closeInventory' })
		SetInterval(client.interval, 200)
		Wait(200)

		if invOpen ~= nil then return end

		TriggerServerEvent('ox_inventory:closeInventory')

		currentInventory = defaultInventory
		client.player:set('invOpen', false)
		defaultInventory.coords = nil
	end
end

RegisterNetEvent('ox_inventory:closeInventory', client.closeInventory)
exports('closeInventory', client.closeInventory)

---@param data updateSlot[]
---@param weight number
local function updateInventory(data, weight)
	local changes = {}
    ---@type table<string, number>
	local itemCount = {}

	for i = 1, #data do
		local v = data[i]

		if not v.inventory or v.inventory == cache.serverId then
			v.inventory = 'player'
			local item = v.item

			if currentWeapon?.slot == item?.slot then
                if item.metadata then
				    currentWeapon.metadata = item.metadata
				    TriggerEvent('ox_inventory:currentWeapon', currentWeapon)
                else
                    currentWeapon = Weapon.Disarm(currentWeapon, true)
                end
			end

			local curItem = PlayerData.inventory[item.slot]

			if curItem and curItem.name then
				itemCount[curItem.name] = (itemCount[curItem.name] or 0) - curItem.count
			end

			if item.count then
				itemCount[item.name] = (itemCount[item.name] or 0) + item.count
			end

			changes[item.slot] = item.count and item or false
			if not item.count then item.name = nil end
			PlayerData.inventory[item.slot] = item.name and item or nil
		end
	end

	SendNUIMessage({ action = 'refreshSlots', data = { items = data, itemCount = itemCount} })

    if weight ~= PlayerData.weight then client.setPlayerData('weight', weight) end

	for itemName, count in pairs(itemCount) do
		local item = Items(itemName)

        if item then
            item.count += count

            TriggerEvent('ox_inventory:itemCount', item.name, item.count)

            if count < 0 then
                if shared.framework == 'esx' then
                    TriggerEvent('esx:removeInventoryItem', item.name, item.count)
                end

                if item.client?.remove then
                    item.client.remove(item.count)
                end
            elseif count > 0 then
                if shared.framework == 'esx' then
                    TriggerEvent('esx:addInventoryItem', item.name, item.count)
                end

                if item.client?.add then
                    item.client.add(item.count)
                end
            end
        end
	end

	client.setPlayerData('inventory', PlayerData.inventory)
	TriggerEvent('ox_inventory:updateInventory', changes)
end

RegisterNetEvent('ox_inventory:updateSlots', function(items, weights)
	if source ~= '' and next(items) then updateInventory(items, weights) end
end)

RegisterNetEvent('ox_inventory:inventoryReturned', function(data)
	if source == '' then return end
	if currentWeapon then currentWeapon = Weapon.Disarm(currentWeapon) end

	lib.notify({ description = locale('items_returned') })
	client.closeInventory()

	local num, items = 0, {}

	for _, slotData in pairs(data[1]) do
		num += 1
		items[num] = { item = slotData, inventory = cache.serverId }
	end

	updateInventory(items, data[3])
end)

RegisterNetEvent('ox_inventory:inventoryConfiscated', function(message)
	if source == '' then return end
	if message then lib.notify({ description = locale('items_confiscated') }) end
	if currentWeapon then currentWeapon = Weapon.Disarm(currentWeapon) end

	client.closeInventory()

	local num, items = 0, {}

	for slot in pairs(PlayerData.inventory) do
		num += 1
		items[num] = { item = { slot = slot }, inventory = cache.serverId }
	end

	updateInventory(items, 0)
end)


---@param point CPoint
local function nearbyDrop(point)
	if not point.instance or point.instance == currentInstance then
        DrawMarker(client.dropmarker.type, point.coords.x, point.coords.y, point.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, client.dropmarker.scale[1], client.dropmarker.scale[2], client.dropmarker.scale[3],
        ---@diagnostic disable-next-line: param-type-mismatch
        client.dropmarker.colour[1], client.dropmarker.colour[2], client.dropmarker.colour[3], 222, false, false, 0, true, false, false, false)
    end
end

---@param point CPoint
local function onEnterDrop(point)
	if not point.instance or point.instance == currentInstance and not point.entity then
		local model = point.model or client.dropmodel

        -- Prevent breaking inventory on invalid point.model instead use default client.dropmodel
        if not IsModelValid(model) and not IsModelInCdimage(model) then
            model = client.dropmodel
        end
		lib.requestModel(model)

		local entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, true, true)

		SetModelAsNoLongerNeeded(model)
		PlaceObjectOnGroundProperly(entity)
		FreezeEntityPosition(entity, true)
		SetEntityCollision(entity, false, true)

		point.entity = entity
	end
end

local function onExitDrop(point)
	local entity = point.entity

	if entity then
		Utils.DeleteEntity(entity)
		point.entity = nil
	end
end

local function createDrop(dropId, data)
	local point = lib.points.new({
		coords = data.coords,
		distance = 16,
		invId = dropId,
		instance = data.instance,
		model = data.model
	})

	if point.model or client.dropprops then
		point.distance = 30
		point.onEnter = onEnterDrop
		point.onExit = onExitDrop
	else
		point.nearby = nearbyDrop
	end

	client.drops[dropId] = point
end

RegisterNetEvent('ox_inventory:createDrop', function(dropId, data, owner, slot)
	if client.drops then
		createDrop(dropId, data)
	end

	if owner == cache.serverId then
		if currentWeapon?.slot == slot then
			currentWeapon = Weapon.Disarm(currentWeapon)
		end

		if invOpen and #(GetEntityCoords(playerPed) - data.coords) <= 1 then
			if not cache.vehicle then
				client.openInventory('drop', dropId)
			else
				SendNUIMessage({
					action = 'setupInventory',
					data = { rightInventory = currentInventory }
				})
			end
		end
	end
end)

RegisterNetEvent('ox_inventory:removeDrop', function(dropId)
	if client.drops then
		local point = client.drops[dropId]

		if point then
			client.drops[dropId] = nil
			point:remove()

			if point.entity then Utils.DeleteEntity(point.entity) end
		end
	end
end)

---@type function?
local function setStateBagHandler(stateId)
	AddStateBagChangeHandler('invOpen', stateId, function(_, _, value)
		invOpen = value
	end)

	AddStateBagChangeHandler('invBusy', stateId, function(_, _, value)
		invBusy = value
	end)

    AddStateBagChangeHandler('canUseWeapons', stateId, function(_, _, value)
        if not value and currentWeapon then
            currentWeapon = Weapon.Disarm(currentWeapon)
        end
    end)

	AddStateBagChangeHandler('instance', stateId, function(_, _, value)
		currentInstance = value

		if client.drops then
			-- Iterate over known drops and remove any points in a different instance (ignoring no instance)
			for dropId, point in pairs(client.drops) do
				if point.instance then
					if point.instance ~= value then
						if point.entity then
							Utils.DeleteEntity(point.entity)
							point.entity = nil
						end

						point:remove()
					else
						-- Recreate the drop using data from the old point
						createDrop(dropId, point)
					end
				end
			end
		end
	end)

	AddStateBagChangeHandler('dead', stateId, function(_, _, value)
		Utils.WeaponWheel()
		PlayerData.dead = value
	end)

	AddStateBagChangeHandler('invHotkeys', stateId, function(_, _, value)
		invHotkeys = value
	end)

	setStateBagHandler = nil
end

RegisterNetEvent('txcl:heal', function()
    if source == '' then return end

    PlayerData.dead = false
end)

lib.onCache('seat', function(seat)
	if seat then
		local hasWeapon = GetCurrentPedVehicleWeapon(cache.ped)

		if hasWeapon then
			return Utils.WeaponWheel(true)
		end
	end

	Utils.WeaponWheel(false)
end)

lib.onCache('vehicle', function()
	if invOpen and (not currentInventory.entity or currentInventory.entity == cache.vehicle) then
		client.closeInventory()
	end
end)

-- Store the equipped weapon on entry; re-equip the same frame we leave (no wait-for-task delay)
CreateThread(function()
	local wasInVehicle = GetVehiclePedIsIn(cache.ped, false) ~= 0
	local justExitedVehicle = false
	local isInVehicle = wasInVehicle

	while true do
		Wait(isInVehicle and 0 or 50)

		local vehicle = GetVehiclePedIsIn(cache.ped, false)
		isInVehicle = vehicle ~= 0

		if not isInVehicle and wasInVehicle then
			justExitedVehicle = true
			if storedWeaponOnVehicleEntry and not manuallyHolsteredInVehicle then
				local slot = storedWeaponOnVehicleEntry.slot
				local storedName = storedWeaponOnVehicleEntry.name

				isReEquippingWeapon = true

				CreateThread(function()
					if GetVehiclePedIsIn(cache.ped, false) ~= 0 then
						isReEquippingWeapon = false
						storedWeaponOnVehicleEntry = nil
						return
					end

					if not PlayerData or not PlayerData.inventory then
						isReEquippingWeapon = false
						storedWeaponOnVehicleEntry = nil
						return
					end

					local item = PlayerData.inventory[slot]
					if not item or item.name ~= storedName then
						isReEquippingWeapon = false
						storedWeaponOnVehicleEntry = nil
						return
					end

					local data = Items[storedName]
					if not data or not data.weapon then
						isReEquippingWeapon = false
						storedWeaponOnVehicleEntry = nil
						return
					end

					local selected = GetSelectedPedWeapon(cache.ped)
					if selected == data.hash or (currentWeapon and currentWeapon.hash == data.hash and currentWeapon.slot == slot) then
						isReEquippingWeapon = false
						storedWeaponOnVehicleEntry = nil
						justExitedVehicle = false
						manuallyHolsteredInVehicle = false
						return
					end

					if currentWeapon then
						skipHotbarUnequip = true
						currentWeapon = Weapon.Disarm(currentWeapon, true)
						skipHotbarUnequip = false
						currentWeapon = nil
					end
					RemoveAllPedWeapons(cache.ped, true)

					data.slot = slot
					currentWeapon = Weapon.Equip(item, data, true, true)
					TriggerServerEvent('ox_inventory:vehicleExitReequipWeapon', slot)

					isReEquippingWeapon = false
					storedWeaponOnVehicleEntry = nil
					justExitedVehicle = false
					manuallyHolsteredInVehicle = false
				end)
			else
				justExitedVehicle = false
				manuallyHolsteredInVehicle = false
			end
		end

		if not isInVehicle and not justExitedVehicle then
			if manuallyHolsteredInVehicle then
				manuallyHolsteredInVehicle = false
			end

			if currentWeapon then
				if not storedWeaponOnVehicleEntry or storedWeaponOnVehicleEntry.slot ~= currentWeapon.slot then
					storedWeaponOnVehicleEntry = {
						slot = currentWeapon.slot,
						name = currentWeapon.name,
						hash = currentWeapon.hash
					}
				end
			elseif not isReEquippingWeapon then
				storedWeaponOnVehicleEntry = nil
			end
		end

		if isInVehicle and not wasInVehicle then
			local canShootFromVehicle = false
			if vehicle ~= 0 then
				local vehicleClass = GetVehicleClass(vehicle)
				local seatIndex = cache.seat
				if vehicleClass == 15 and seatIndex and seatIndex > 0 then
					canShootFromVehicle = true
				end
			end

			if not canShootFromVehicle and not storedWeaponOnVehicleEntry and currentWeapon then
				storedWeaponOnVehicleEntry = {
					slot = currentWeapon.slot,
					name = currentWeapon.name,
					hash = currentWeapon.hash
				}
			end

			manuallyHolsteredInVehicle = false
		end

		wasInVehicle = isInVehicle
	end
end)

RegisterNetEvent('ox_inventory:setPlayerInventory', function(currentDrops, inventory, weight, player, hotbar)
	if source == '' then return end

    ---@class PlayerData
    ---@field inventory table<number, SlotWithItem?>
    ---@field weight number
    ---@field groups table<string, number>
	PlayerData = player
	PlayerData.id = cache.playerId
	PlayerData.source = cache.serverId
    PlayerData.maxWeight = shared.playerweight

	-- Load this character's hotbar from the server (migrate legacy KVP once if needed)
	hotbarReady = false
	loadHotbarFromServer(hotbar)

	setmetatable(PlayerData, {
		__index = function(self, key)
			if key == 'ped' then
				return PlayerPedId()
			end
		end
	})

	if setStateBagHandler then setStateBagHandler(('player:%s'):format(cache.serverId)) end

	local ItemData = table.create(0, #Items)

	for _, v in pairs(Items --[[@as table<string, OxClientItem>]]) do
		local buttons = v.buttons and {} or nil

		if buttons then
			for i = 1, #v.buttons do
				buttons[i] = {label = v.buttons[i].label, group = v.buttons[i].group}
			end
		end

		ItemData[v.name] = {
			label = v.label,
			stack = v.stack,
			close = v.close,
			count = 0,
			description = v.description,
			buttons = buttons,
			ammoName = v.ammoname,
			image = v.client?.image,
			weapon = v.weapon,
		}
	end

	for _, data in pairs(inventory) do
		local item = Items[data.name]

		if item then
			item.count += data.count
			ItemData[data.name].count += data.count
			local add = item.client?.add

			if add then
				add(item.count)
			end
		end
	end

	local phone = Items.phone

	if phone and phone.count < 1 then
		pcall(function()
			return exports.npwd:setPhoneDisabled(true)
		end)
	end

	client.setPlayerData('inventory', inventory)
	client.setPlayerData('weight', weight)
	currentWeapon = nil
	Weapon.ClearAll()

	local uiLocales = {}
	local locales = lib.getLocales()

	for k, v in pairs(locales) do
		if k:find('^ui_')then
			uiLocales[k] = v
		end
	end

	uiLocales['$'] = locales['$']
	uiLocales.ammo_type = locales.ammo_type

	client.drops = currentDrops

	for dropId, data in pairs(currentDrops) do
		createDrop(dropId, data)
	end

	local hasTextUi
	local uiOptions = { icon = 'fa-id-card' }

	---@param point CPoint
	local function nearbyLicense(point)
		---@diagnostic disable-next-line: param-type-mismatch
		DrawMarker(2, point.coords.x, point.coords.y, point.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 30, 150, 30, 222, false, false, 0, true, false, false, false)

		if point.isClosest and point.currentDistance < 1.2 then
			if not hasTextUi then
				hasTextUi = point
				lib.showTextUI(point.message, uiOptions)
			end

			if IsControlJustReleased(0, 38) then
				lib.callback('ox_inventory:buyLicense', 1000, function(success, message)
					if success ~= nil then
						lib.notify({
							id = message,
							type = success == false and 'error' or 'success',
							description = locale(message, locale('license', point.type:gsub("^%l", string.upper)))
						})
					end
				end, point.invId)
			end
		elseif hasTextUi == point then
			hasTextUi = false
			lib.hideTextUI()
		end
	end

	for id, data in pairs(lib.load('data.licenses') or {}) do
		lib.points.new({
			coords = data.coords,
			distance = 16,
			inv = 'license',
			type = data.name,
			price = data.price,
			invId = id,
			nearby = nearbyLicense,
			message = ('**%s**  \n%s'):format(locale('purchase_license', data.name), locale('interact_prompt', GetControlInstructionalButton(0, 38, true):sub(3)))
		})
	end

	while not client.uiLoaded do Wait(50) end

	SendNUIMessage({
		action = 'init',
		data = {
			locale = uiLocales,
			items = ItemData,
			leftInventory = {
				id = cache.playerId,
				slots = shared.playerslots,
				items = PlayerData.inventory,
				maxWeight = shared.playerweight,
			},
			imagepath = client.imagepath,
			hotbarBinds = getHotbarPayload(),
			hotbarHud = hotbarHudVisible,
			quickCraft = QuickCraft.GetRecipes(),
			navPanels = {
				craft = client.navcraft,
				wearables = client.navwearables,
				settings = client.navsettings,
			},
			uiOptions = {
				showDurability = shared.durability,
			},
		}
	})

	PlayerData.loaded = true

	if not client.disablesetupnotification then
		lib.notify({ description = locale('inventory_setup') })
	end

	Shops.refreshShops()
	Inventory.Stashes()
	Inventory.Evidence()

	if registerCommands then registerCommands() end

	TriggerEvent('ox_inventory:updateInventory', PlayerData.inventory)

	client.interval = SetInterval(function()
        local canSteal = canOpenTarget(playerPed)

        if canSteal ~= client.player:get('canSteal') then
            client.player:setr('canSteal', canSteal)
        end

		if invOpen == false then
			playerCoords = GetEntityCoords(playerPed)

			if currentWeapon and IsPedUsingActionMode(playerPed) then
				SetPedUsingActionMode(playerPed, false, -1, 'DEFAULT_ACTION')
			end

		elseif invOpen == true then
			if not canOpenInventory() then
				client.closeInventory()
			else
				playerCoords = GetEntityCoords(playerPed)

				if not currentInventory.ignoreSecurityChecks then
                    local maxDistance = (currentInventory.distance or currentInventory.type == 'stash' and 4.8 or 1.8) + 0.2

					if currentInventory.type == 'otherplayer' then
						local id = GetPlayerFromServerId(currentInventory.id --[[@as number]])
						local ped = GetPlayerPed(id)
						local pedCoords = GetEntityCoords(ped)

						if not id or #(playerCoords - pedCoords) > maxDistance or (not client.hasGroup(shared.police) and not Player(currentInventory.id).state.canSteal) then
							client.closeInventory()
							lib.notify({ id = 'inventory_lost_access', type = 'error', description = locale('inventory_lost_access') })
						else
							TaskTurnPedToFaceCoord(playerPed, pedCoords.x, pedCoords.y, pedCoords.z, 50)
						end

					elseif currentInventory.coords and (#(playerCoords - currentInventory.coords) > maxDistance or canSteal) then
						client.closeInventory()
						lib.notify({ id = 'inventory_lost_access', type = 'error', description = locale('inventory_lost_access') })
					end
				end
			end
		end

		if client.parachute and GetPedParachuteState(playerPed) ~= -1 then
			Utils.DeleteEntity(client.parachute[1])
			client.parachute = false
		end

		if EnableWeaponWheel then return end

		local weaponHash = GetSelectedPedWeapon(playerPed)

		if currentWeapon then
			if weaponHash ~= currentWeapon.hash and currentWeapon.timer then
				local weaponCount = Items[currentWeapon.name]?.count

				if weaponCount and weaponCount > 0 then
					SetCurrentPedWeapon(playerPed, currentWeapon.hash, true)
					SetAmmoInClip(playerPed, currentWeapon.hash, currentWeapon.metadata.ammo)
					SetPedCurrentWeaponVisible(playerPed, true, false, false, false)

					weaponHash = GetSelectedPedWeapon(playerPed)
				end

				if weaponHash ~= currentWeapon.hash and not isReEquippingWeapon then
					local canShootFromVehicle = false
					if cache.vehicle then
						local vehicleClass = GetVehicleClass(cache.vehicle)
						if vehicleClass == 15 and cache.seat and cache.seat > 0 then
							canShootFromVehicle = true
						end
					end

					if not canShootFromVehicle then
						if cache.vehicle or (not cache.vehicle and not storedWeaponOnVehicleEntry) then
							if currentWeapon.group ~= `GROUP_PISTOL` and currentWeapon.group ~= `GROUP_STUNGUN` then
								if not storedWeaponOnVehicleEntry or storedWeaponOnVehicleEntry.slot ~= currentWeapon.slot then
									storedWeaponOnVehicleEntry = {
										slot = currentWeapon.slot,
										name = currentWeapon.name,
										hash = currentWeapon.hash,
										serial = currentWeapon.metadata and currentWeapon.metadata.serial or nil,
									}
									sendHotbarEquipped(storedWeaponOnVehicleEntry)
								end
							end
						end

						currentWeapon = Weapon.Disarm(currentWeapon, true)
					end
				end
			end
		elseif client.weaponmismatch and not client.ignoreweapons[weaponHash] then
			local weaponType = GetWeapontypeGroup(weaponHash)

			if weaponType ~= 0 and weaponType ~= `GROUP_UNARMED` then
				Weapon.Disarm(currentWeapon, true)
			end
		end
	end, 200)

	local playerId = cache.playerId
	local EnableKeys = client.enablekeys
	local DisablePlayerVehicleRewards = DisablePlayerVehicleRewards
	local DisableAllControlActions = DisableAllControlActions
	local HideHudAndRadarThisFrame = HideHudAndRadarThisFrame
	local EnableControlAction = EnableControlAction
	local DisablePlayerFiring = DisablePlayerFiring
	local HudWeaponWheelIgnoreSelection = HudWeaponWheelIgnoreSelection
	local DisableControlAction = DisableControlAction
	local IsPedShooting = IsPedShooting
	local IsControlJustReleased = IsControlJustReleased

	client.tick = SetInterval(function()
		DisablePlayerVehicleRewards(playerId)

		if invOpen then
			DisableAllControlActions(0)
			HideHudAndRadarThisFrame()

			for i = 1, #EnableKeys do
				EnableControlAction(0, EnableKeys[i], true)
			end

			-- Keep the ped still even if enablekeys / drop UI would restore WASD
			DisableControlAction(0, 30, true)
			DisableControlAction(0, 31, true)
			DisableControlAction(0, 21, true)
			DisableControlAction(0, 22, true)
			DisableControlAction(0, 32, true)
			DisableControlAction(0, 33, true)
			DisableControlAction(0, 34, true)
			DisableControlAction(0, 35, true)
		else
			if invBusy then
				DisableControlAction(0, 23, true)
				DisableControlAction(0, 36, true)
			end

			if usingItem or invOpen or IsPedCuffed(playerPed) then
				DisablePlayerFiring(playerId, true)
			end

			if not EnableWeaponWheel then
				HudWeaponWheelIgnoreSelection()
				DisableControlAction(0, 37, true)
			end

			if currentWeapon and currentWeapon.timer then
				DisableControlAction(0, 80, true)
				DisableControlAction(0, 140, true)

				if (shared.durability and currentWeapon.metadata.durability <= 0) or not currentWeapon.timer then
					DisablePlayerFiring(playerId, true)
				elseif client.aimedfiring and not currentWeapon.melee and currentWeapon.group ~= `GROUP_PETROLCAN` and not IsPlayerFreeAiming(playerId) then
					DisablePlayerFiring(playerId, true)
				end

				local weaponAmmo = currentWeapon.metadata.ammo

				if not invBusy and currentWeapon.timer ~= 0 and currentWeapon.timer < GetGameTimer() then
					currentWeapon.timer = 0

					if weaponAmmo then
						TriggerServerEvent('ox_inventory:updateWeapon', 'ammo', weaponAmmo)

						if client.autoreload and currentWeapon.ammo and GetAmmoInPedWeapon(playerPed, currentWeapon.hash) == 0 then
							local slotId = Inventory.GetSlotIdWithItem(currentWeapon.ammo, { type = currentWeapon.metadata.specialAmmo }, false)

							if slotId then
								CreateThread(function() useSlot(slotId) end)
							end
						end

					elseif shared.durability and currentWeapon.metadata.durability then
						TriggerServerEvent('ox_inventory:updateWeapon', 'melee', currentWeapon.melee)
						currentWeapon.melee = 0
					end
				elseif weaponAmmo then
					if IsPedShooting(playerPed) then
						local currentAmmo
						-- Item durability field is also the per-shot drain rate for cans/weapons
						local durabilityDrain = Items[currentWeapon.name].durability

						if currentWeapon.group == `GROUP_PETROLCAN` or currentWeapon.group == `GROUP_FIREEXTINGUISHER` then
							currentAmmo = weaponAmmo - durabilityDrain < 0 and 0 or weaponAmmo - durabilityDrain
							-- Fuel level lives in ammo; only mirror to durability when that system is on
							if shared.durability then
								currentWeapon.metadata.durability = currentAmmo
							end
							currentWeapon.metadata.ammo = (weaponAmmo < currentAmmo) and 0 or currentAmmo

							if currentAmmo <= 0 then
								SetPedInfiniteAmmo(playerPed, false, currentWeapon.hash)
							end
						else
							currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)

							if currentAmmo < weaponAmmo then
								currentAmmo = (weaponAmmo < currentAmmo) and 0 or currentAmmo
								currentWeapon.metadata.ammo = currentAmmo
								if shared.durability then
									currentWeapon.metadata.durability = currentWeapon.metadata.durability - (durabilityDrain * math.abs((weaponAmmo or 0.1) - currentAmmo))
								end
							end
						end

						if currentAmmo <= 0 then
							if cache.vehicle then
								TaskSwapWeapon(playerPed, true)
							end

							currentWeapon.timer = GetGameTimer() + 200
						else currentWeapon.timer = GetGameTimer() + (GetWeaponTimeBetweenShots(currentWeapon.hash) * 1000) + 100 end
					end
				elseif currentWeapon.throwable then
					if not invBusy and IsControlPressed(0, 24) then
						invBusy = 1

						CreateThread(function()
							local weapon = currentWeapon

							while currentWeapon and (not IsPedWeaponReadyToShoot(cache.ped) or IsDisabledControlPressed(0, 24)) and GetSelectedPedWeapon(playerPed) == weapon.hash do
								Wait(0)
							end

							if GetSelectedPedWeapon(playerPed) == weapon.hash then Wait(700) end

							while IsPedPlantingBomb(playerPed) do Wait(0) end

							TriggerServerEvent('ox_inventory:updateWeapon', 'throw', nil, weapon.slot)
							client.player:setr('invBusy', false)

							currentWeapon = nil

							RemoveWeaponFromPed(playerPed, weapon.hash)
							TriggerEvent('ox_inventory:currentWeapon')
						end)
					end
				elseif currentWeapon.melee and IsControlJustReleased(0, 24) and IsPedPerformingMeleeAction(playerPed) then
					currentWeapon.melee += 1
					currentWeapon.timer = GetGameTimer() + 200
				end
			end
		end
	end)

	client.player:setr('invBusy', false)
	client.player:set('invOpen', false)
	client.player:set('invHotkeys', true)
	client.player:set('canUseWeapons', true)
	collectgarbage('collect')
end)

AddEventHandler('onResourceStop', function(resourceName)
	if shared.resource == resourceName then
		client.onLogout()
	end
end)

RegisterNetEvent('ox_inventory:viewInventory', function(left, right)
	if source == '' then return end

	client.player:set('invOpen', true)
	SetInterval(client.interval, 100)
	SetNuiFocus(true, true)
	SetNuiFocusKeepInput(true)
	closeTrunk()

	if client.screenblur then Utils.blurIn() end

	currentInventory = right or defaultInventory
	currentInventory.ignoreSecurityChecks = true
    currentInventory.type = 'inspect'
	left.items = PlayerData.inventory
	left.groups = PlayerData.groups

	SendNUIMessage({
		action = 'setupInventory',
		data = {
			leftInventory = left,
			rightInventory = currentInventory
		}
	})
end)

RegisterNUICallback('uiLoaded', function(_, cb)
	client.uiLoaded = true
	cb(1)

	if PlayerData.loaded then
		SendNUIMessage({ action = 'setupHotbar', data = getHotbarPayload() })
		SendNUIMessage({ action = 'setHotbarHud', data = hotbarHudVisible })
	end
end)

RegisterNUICallback('setHotbarHud', function(data, cb)
	if type(data) ~= 'table' or data.visible == nil then return cb(0) end
	setHotbarHudVisible(data.visible)
	cb(1)
end)

RegisterNUICallback('getItemData', function(itemName, cb)
	cb(Items[itemName])
end)

RegisterNUICallback('removeComponent', function(data, cb)
	cb(1)

	if not currentWeapon then
		return TriggerServerEvent('ox_inventory:updateWeapon', 'component', data)
	end

	if data.slot ~= currentWeapon.slot then
		return lib.notify({ id = 'weapon_hand_wrong', type = 'error', description = locale('weapon_hand_wrong') })
	end

	local itemSlot = PlayerData.inventory[currentWeapon.slot]

    if not itemSlot then return end

	for _, component in pairs(Items[data.component].client.component) do
		if HasPedGotWeaponComponent(playerPed, currentWeapon.hash, component) then
			for k, v in pairs(itemSlot.metadata.components) do
				if v == data.component then
					local success = lib.callback.await('ox_inventory:updateWeapon', false, 'component', k)

					if success then
						RemoveWeaponComponentFromPed(playerPed, currentWeapon.hash, component)
						TriggerEvent('ox_inventory:updateWeaponComponent', 'removed', component, data.component)
					end

					break
				end
			end
		end
	end
end)

RegisterNUICallback('removeAmmo', function(slot, cb)
	cb(1)
	local slotData = PlayerData.inventory[slot]

	if not slotData or not slotData.metadata.ammo or slotData.metadata.ammo == 0 then return end

	local success = lib.callback.await('ox_inventory:removeAmmoFromWeapon', false, slot)

	if success and slot == currentWeapon?.slot then
		SetPedAmmo(playerPed, currentWeapon.hash, 0)
	end
end)

RegisterNUICallback('useItem', function(slot, cb)
	useSlot(slot --[[@as number]])
	cb(1)
end)

RegisterNUICallback('bindHotbar', function(data, cb)
	local index = tonumber(data.index)
	if not index or index < 1 or index > HOTBAR_SIZE then return cb(0) end

	local name = data.name
	local slot = tonumber(data.slot)
	if type(name) ~= 'string' or not slot then return cb(0) end

	local item = PlayerData.inventory and PlayerData.inventory[slot]
	if not item or item.name ~= name then
		slot = Inventory.GetSlotIdWithItem(name, data.serial and { serial = data.serial } or nil)
		item = slot and PlayerData.inventory[slot]
		if not item then return cb(0) end
	end

	hotbarBinds[index] = {
		slot = item.slot,
		name = item.name,
		serial = item.metadata and item.metadata.serial or nil
	}
	saveHotbarBinds()
	cb(1)
end)

RegisterNUICallback('unbindHotbar', function(data, cb)
	local index = tonumber(data.index)
	if index and index >= 1 and index <= HOTBAR_SIZE then
		hotbarBinds[index] = nil
		saveHotbarBinds()
	end
	cb(1)
end)

RegisterNUICallback('swapHotbar', function(data, cb)
	local from, to = tonumber(data.from), tonumber(data.to)
	if not from or not to or from < 1 or to < 1 or from > HOTBAR_SIZE or to > HOTBAR_SIZE then return cb(0) end

	hotbarBinds[from], hotbarBinds[to] = hotbarBinds[to], hotbarBinds[from]
	saveHotbarBinds()
	cb(1)
end)

local function giveItemToTarget(serverId, slotId, count)
    if type(slotId) ~= 'number' then return TypeError('slotId', 'number', type(slotId)) end
    if count and type(count) ~= 'number' then return TypeError('count', 'number', type(count)) end

    if slotId == currentWeapon?.slot then
        currentWeapon = Weapon.Disarm(currentWeapon)
    end

    Utils.PlayAnim(0, 'mp_common', 'givetake1_a', 1.0, 1.0, 2000, 50, 0.0, 0, 0, 0)

    local notification = lib.callback.await('ox_inventory:giveItem', false, slotId, serverId, count or 0)

    if notification then
        lib.notify({ type = 'error', description = locale(table.unpack(notification)) })
    end
end

exports('giveItemToTarget', giveItemToTarget)

local function isGiveTargetValid(ped, coords)
    if cache.vehicle and GetVehiclePedIsIn(ped, false) == cache.vehicle then
        return true
    end

    local entity = Utils.Raycast(1|4|8|16, coords + vec3(0, 0, 0.5), 0.2)

    return entity == ped and IsEntityVisible(ped)
end

RegisterNUICallback('giveItem', function(data, cb)
	cb(1)

    if usingItem then return end

	if client.giveplayerlist then
		local coords = cache.vehicle and GetWorldPositionOfEntityBone(playerPed, 0) or GetEntityCoords(playerPed)

		local nearbyPlayers = lib.getNearbyPlayers(coords, 3.0)
        local nearbyCount = #nearbyPlayers

		if nearbyCount == 0 then return end

        if nearbyCount == 1 then
			local option = nearbyPlayers[1]

            if not isGiveTargetValid(option.ped, option.coords) then return end

            return giveItemToTarget(GetPlayerServerId(option.id), data.slot, data.count)
        end

        local giveList, n = {}, 0

		for i = 1, #nearbyPlayers do
			local option = nearbyPlayers[i]

            if isGiveTargetValid(option.ped, option.coords) then
				option.id = GetPlayerServerId(option.id)
				local playerName = Utils.getPlayerName(option.id)
                ---@diagnostic disable-next-line: inject-field
				option.label = playerName
				n += 1
				giveList[n] = option
			end
		end

        if n == 0 then return end

		lib.registerMenu({
			id = 'ox_inventory:givePlayerList',
			title = 'Give item',
			options = giveList,
		}, function(selected)
            giveItemToTarget(giveList[selected].id, data.slot, data.count)
        end)

		return lib.showMenu('ox_inventory:givePlayerList')
	end

    if cache.vehicle then
		local seats = GetVehicleMaxNumberOfPassengers(cache.vehicle) - 1

		if seats >= 0 then
			local passenger = GetPedInVehicleSeat(cache.vehicle, cache.seat - 2 * (cache.seat % 2) + 1)

			if passenger ~= 0 and IsEntityVisible(passenger) then
                return giveItemToTarget(GetPlayerServerId(NetworkGetPlayerIndexFromPed(passenger)), data.slot, data.count)
			end
		end

        return
	end

    local entity = Utils.Raycast(1|2|4|8|16, GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 3.0, 0.5), 0.2)

    if entity and IsPedAPlayer(entity) and IsEntityVisible(entity) and #(GetEntityCoords(playerPed, true) - GetEntityCoords(entity, true)) < 3.0 then
        return giveItemToTarget(GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity)), data.slot, data.count)
    end
end)

RegisterNUICallback('useButton', function(data, cb)
	useButton(data.id, data.slot)
	cb(1)
end)

RegisterNUICallback('exit', function(_, cb)
	-- Activating the wearables pause overlay can inject Escape into NUI
	if Wearables.ShouldIgnoreExit() then
		cb(1)
		return
	end
	client.closeInventory()
	cb(1)
end)

RegisterNUICallback('toggleRecycler', function(data, cb)
	local success, running, process = lib.callback.await('ox_inventory:toggleRecycler', false, data and data.running)
	cb({ success = success, running = running, process = process })
end)

RegisterNUICallback('toggleFurnace', function(data, cb)
	local success, running, process = lib.callback.await('ox_inventory:toggleFurnace', false, data and data.running)
	cb({ success = success, running = running, process = process })
end)

lib.callback.register('ox_inventory:startCrafting', function(id, recipe)
	recipe = CraftingBenches[id].items[recipe]

	return lib.progressCircle({
		label = locale('crafting_item', recipe.metadata?.label or Items[recipe.name].label),
		duration = recipe.duration or 3000,
		canCancel = true,
		disable = {
			move = true,
			combat = true,
		},
		anim = {
			dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
			clip = 'machinic_loop_mechandplayer',
		}
	})
end)

local swapActive = false

---Synchronise and validate all item movement between the NUI and server.
RegisterNUICallback('swapItems', function(data, cb)
    if swapActive or not invOpen or invBusy or usingItem then return cb(false) end

    swapActive = true

	if data.toType == 'newdrop' then
		if cache.vehicle or IsPedFalling(playerPed) then
			swapActive = false
			return cb(false)
		end

		local coords = GetEntityCoords(playerPed)

		if IsEntityInWater(playerPed) then
			local destination = vec3(coords.x, coords.y, -200)
			local handle = StartShapeTestLosProbe(coords.x, coords.y, coords.z, destination.x, destination.y, destination.z, 511, cache.ped, 4)

			while true do
				Wait(0)
				local retval, hit, endCoords = GetShapeTestResult(handle)

				if retval ~= 1 then
					if not hit then return end

					data.coords = vec3(endCoords.x, endCoords.y, endCoords.z + 1.0)

					break
				end
			end
		else
			data.coords = coords
		end
    end

	if currentInstance then
		data.instance = currentInstance
	end

	if currentWeapon and data.fromType ~= data.toType then
		if (data.fromType == 'player' and data.fromSlot == currentWeapon.slot) or (data.toType == 'player' and data.toSlot == currentWeapon.slot) then
			currentWeapon = Weapon.Disarm(currentWeapon, true)
		end
	end

	local success, response, weaponSlot = lib.callback.await('ox_inventory:swapItems', false, data)
    swapActive = false

	cb(success or false)

	if success then
        if weaponSlot and currentWeapon then
            currentWeapon.slot = weaponSlot
        end

		if response then
			updateInventory(response.items, response.weight)
		end
	elseif response then
		if type(response) == 'table' then
			SendNUIMessage({ action = 'refreshSlots', data = { items = response } })
		else
			lib.notify({ type = 'error', description = locale(response) })
		end
	end
end)

RegisterNUICallback('buyItem', function(data, cb)
	---@type boolean, false | { [1]: number, [2]: SlotWithItem, [3]: SlotWithItem | false, [4]: number}, NotifyProps
	local response, data, message = lib.callback.await('ox_inventory:buyItem', 100, data)

	if data then
		updateInventory({
			{
				item = data[2],
				inventory = cache.serverId
			}
		}, data[4])

		if data[3] then
			SendNUIMessage({
				action = 'refreshSlots',
				data = {
					items = {
						{
							item = data[3],
							inventory = 'shop'
						}
					}
				}
			})
		end
	end

	if message then
		lib.notify(message)
	end

	cb(response)
end)

-- Drag a player stack onto a pawn listing (classic shop grid, no cart)
RegisterNUICallback('sellItem', function(data, cb)
	---@type boolean, false | { [1]: number, [2]: SlotWithItem | { slot: number }, [3]: SlotWithItem | table | false, [4]: number}, NotifyProps
	local response, payload, message = lib.callback.await('ox_inventory:sellItem', 100, data)

	if payload then
		local updates = {
			{
				item = payload[2],
				inventory = cache.serverId
			}
		}

		if payload[3] then
			if payload[3].slot then
				updates[#updates + 1] = { item = payload[3], inventory = cache.serverId }
			elseif type(payload[3]) == 'table' then
				for i = 1, #payload[3] do
					updates[#updates + 1] = { item = payload[3][i], inventory = cache.serverId }
				end
			end
		end

		updateInventory(updates, payload[4])
	end

	if message then
		lib.notify(message)
	end

	cb(response or false)
end)

-- Atomic multi-item shop checkout (cart)
RegisterNUICallback('buyCart', function(data, cb)
	---@type boolean, false | { [1]: table, [2]: table, [3]: number }, NotifyProps
	local response, payload, message = lib.callback.await('ox_inventory:buyCart', 100, data)

	if payload then
		local playerUpdates, shopUpdates, weight = payload[1], payload[2], payload[3]

		if playerUpdates and #playerUpdates > 0 then
			updateInventory(playerUpdates, weight)
		end

		if shopUpdates and #shopUpdates > 0 then
			SendNUIMessage({
				action = 'refreshSlots',
				data = { items = shopUpdates }
			})
		end
	end

	if message then
		lib.notify(message)
	end

	cb(response or false)
end)

RegisterNUICallback('sellCart', function(data, cb)
	---@type boolean, false | { [1]: table, [2]: table, [3]: number }, NotifyProps
	local response, payload, message = lib.callback.await('ox_inventory:sellCart', 100, data)

	if payload then
		local playerUpdates, shopUpdates, weight = payload[1], payload[2], payload[3]

		if playerUpdates and #playerUpdates > 0 then
			updateInventory(playerUpdates, weight)
		elseif weight then
			client.setPlayerData('weight', weight)
		end

		if shopUpdates and #shopUpdates > 0 then
			SendNUIMessage({
				action = 'refreshSlots',
				data = { items = shopUpdates }
			})
		end
	end

	if message then
		lib.notify(message)
	end

	cb(response or false)
end)

RegisterNUICallback('notify', function(data, cb)
	cb(1)
	if type(data) == 'table' then lib.notify(data) end
end)

RegisterNUICallback('craftItem', function(data, cb)
	cb(true)

	local id, index = currentInventory.id, currentInventory.index

	for i = 1, data.count do
		local success, response = lib.callback.await('ox_inventory:craftItem', 200, id, index, data.fromSlot, data.toSlot)

		if not success then
			if response then lib.notify({ type = 'error', description = locale(response or 'cannot_perform') }) end
			break
		end
	end

	if currentInventory.type ~= 'crafting' then
		client.openInventory('crafting', { id = id, index = index })
	end
end)

RegisterNUICallback('unlockCraftRecipe', function(data, cb)
	local id, index = currentInventory.id, currentInventory.index
	local success = lib.callback.await('ox_inventory:unlockCraftRecipe', 200, id, data.recipeSlot, data.method)
	if success then
		client.openInventory('crafting', { id = id, index = index })
	else
		lib.notify({ type = 'error', description = locale('recipe_locked') })
	end
	cb(success and true or false)
end)

RegisterNUICallback('researchCraftRecipe', function(_, cb)
	local benchId, index = currentInventory.benchId, currentInventory.index
	local success, err = lib.callback.await('ox_inventory:researchCraftRecipe', 200)
	if success then
		client.openInventory('research', { id = benchId, index = index })
	else
		lib.notify({ type = 'error', description = locale(err or 'recipe_locked') })
	end
	cb(success and true or false)
end)

-- Quick craft from the inventory panel (independent of crafting benches)
RegisterNUICallback('quickCraftItem', function(data, cb)
	cb(true)

	local recipeId = data.recipeId
	if not recipeId then return end

	for _ = 1, data.count or 1 do
		local success, response = lib.callback.await('ox_inventory:quickCraftItem', false, recipeId)

		if not success then
			if response then lib.notify({ type = 'error', description = locale(response or 'cannot_perform') }) end
			break
		end
	end
end)

lib.callback.register('ox_inventory:getVehicleData', function(netid)
	local entity = NetworkGetEntityFromNetworkId(netid)

	if entity then
		return GetEntityModel(entity), GetVehicleClass(entity)
	end
end)
