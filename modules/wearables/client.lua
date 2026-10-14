if not lib then return end

local Utils = require 'modules.utils.client'

local HUD_PAUSE_BG = 117
local MENU_HASH = `FE_MENU_VERSION_EMPTY_NO_BACKGROUND`

local previewActive = false
local previewGen = 0
local previewPed
local savedBlur = false
local ignoreExitUntil = 0

-- The pause menu keeps the copy it was given, so the preview is cloned again whenever
-- the player's clothes or props change (a mask, a bag, a vest going on or off).
local pedHidden = false
local shownLook
local LOOK_PROPS = { 0, 1, 2, 6, 7 }

local function lookOf(ped)
	local parts = { GetEntityModel(ped) }
	for component = 0, 11 do
		parts[#parts + 1] = GetPedDrawableVariation(ped, component)
		parts[#parts + 1] = GetPedTextureVariation(ped, component)
	end
	for _, prop in ipairs(LOOK_PROPS) do
		parts[#parts + 1] = GetPedPropIndex(ped, prop)
		parts[#parts + 1] = GetPedPropTextureIndex(ped, prop)
	end
	return table.concat(parts, ',')
end

local function deletePreviewPed()
	if previewPed and DoesEntityExist(previewPed) then
		SetEntityAsMissionEntity(previewPed, true, true)
		DeletePed(previewPed)
		if DoesEntityExist(previewPed) then
			DeleteEntity(previewPed)
		end
	end
	previewPed = nil
end

-- The pause menu draws its own copy; the world clone must never be seen.
local function hideClone(ped, relocate)
	if not ped or not DoesEntityExist(ped) then return end

	if relocate then
		local coords = GetEntityCoords(cache.ped or PlayerPedId())
		SetEntityCoords(ped, coords.x, coords.y, coords.z - 100.0, false, false, false, false)
	end

	FreezeEntityPosition(ped, true)
	SetEntityCollision(ped, false, false)
	SetEntityVisible(ped, false, false)
	SetEntityAlpha(ped, 0, false)
	SetEntityInvincible(ped, true)
	NetworkSetEntityInvisibleToNetwork(ped, true)
end

local function restorePauseBg()
	-- Default pause-menu overlay colour
	ReplaceHudColourWithRgba(HUD_PAUSE_BG, 0, 0, 0, 186)
end

local function shouldIgnoreExit()
	return GetGameTimer() < ignoreExitUntil
end

local function armIgnoreExit()
	ignoreExitUntil = GetGameTimer() + 1000
	client.wearablesPreview = true
end

local function stopWearablesPreview()
	previewGen += 1

	if not previewActive then
		deletePreviewPed()
		return
	end

	previewActive = false
	-- Closing the overlay injects Escape and leaves IsPauseMenuActive true for a moment
	armIgnoreExit()

	SetPauseMenuPedSleepState(false)
	SetFrontendActive(false)
	deletePreviewPed()
	restorePauseBg()

	if IsNuiFocused() then
		SetNuiFocus(true, true)
	end

	if savedBlur and client.screenblur then
		Utils.blurIn()
	end
	savedBlur = false

	CreateThread(function()
		local untilTime = ignoreExitUntil
		local gen = previewGen
		while GetGameTimer() < untilTime and previewGen == gen do
			DisableControlAction(0, 199, true)
			DisableControlAction(0, 200, true)
			if IsPauseMenuActive() then
				SetFrontendActive(false)
			end
			Wait(0)
		end
		-- Don't clear the flag if wearables was reopened
		if previewGen == gen and not previewActive then
			client.wearablesPreview = false
		end
	end)
end

-- Every frame while the preview is up.
local function holdFrame(extra)
	hideClone(previewPed)
	if extra then hideClone(extra) end
	SetMouseCursorVisibleInMenus(false)
	DisableControlAction(0, 199, true)
	DisableControlAction(0, 200, true)
end

-- Hands the pause menu a fresh clone once its clothes have streamed in (else the menu
-- copies the old ones), then deletes the old clone.
local function refreshPreview(gen)
	local playerPed = PlayerPedId()
	local look = lookOf(playerPed)
	local fresh = ClonePed(playerPed, false, false, false)
	if not fresh or fresh == 0 then
		shownLook = look -- don't retry every check; the next change will
		return
	end

	SetEntityAsMissionEntity(fresh, true, true)
	hideClone(fresh, true)

	local timeout = GetGameTimer() + 1000
	while not HaveAllStreamingRequestsCompleted(fresh) and GetGameTimer() < timeout
		and previewActive and previewGen == gen and not pedHidden do
		holdFrame(fresh)
		Wait(0)
	end

	if not previewActive or previewGen ~= gen or pedHidden then
		SetEntityAsMissionEntity(fresh, true, true)
		DeletePed(fresh)
		return
	end

	local old = previewPed
	previewPed = fresh
	shownLook = look
	GivePedToPauseMenu(fresh, 2)
	SetPauseMenuPedLighting(true)
	SetPauseMenuPedSleepState(true)
	hideClone(fresh)

	if old and DoesEntityExist(old) then
		SetEntityAsMissionEntity(old, true, true)
		DeletePed(old)
		if DoesEntityExist(old) then DeleteEntity(old) end
	end
end

---Pause-menu clone ped (studio lighting) instead of a scripted cam on the real player.
local function startWearablesPreview()
	if previewActive then return end

	previewActive = true
	pedHidden = false
	armIgnoreExit()
	previewGen += 1
	local gen = previewGen

	savedBlur = client.screenblur == true
	if client.screenblur then
		Utils.blurOut()
	end

	CreateThread(function()
		-- Previous overlay may still be shutting down; wait it out before opening a new one
		local timeout = GetGameTimer() + 750
		while previewGen == gen and previewActive and IsPauseMenuActive() and GetGameTimer() < timeout do
			SetFrontendActive(false)
			Wait(0)
		end
		if previewGen ~= gen or not previewActive then return end

		deletePreviewPed()

		SetFrontendActive(true)
		ActivateFrontendMenu(MENU_HASH, false, -1)
		ReplaceHudColourWithRgba(HUD_PAUSE_BG, 0, 0, 0, 0)
		SetNuiFocus(true, true)
		SetMouseCursorVisibleInMenus(false)

		local playerPed = PlayerPedId()
		shownLook = lookOf(playerPed)
		local cloned = ClonePed(playerPed, false, false, false)
		if not cloned or cloned == 0 then
			if previewGen == gen then stopWearablesPreview() end
			return
		end

		SetEntityAsMissionEntity(cloned, true, true)
		hideClone(cloned, true)
		previewPed = cloned

		-- Keep pause controls dead while the overlay boots (GivePedToPauseMenu needs a short delay)
		local readyAt = GetGameTimer() + 500
		while previewActive and previewGen == gen and GetGameTimer() < readyAt do
			holdFrame()
			Wait(0)
		end
		if previewGen ~= gen or not previewActive then
			deletePreviewPed()
			return
		end

		GivePedToPauseMenu(cloned, 2)
		SetPauseMenuPedLighting(true)
		SetPauseMenuPedSleepState(true)
		hideClone(cloned)

		-- Frontend steals the cursor otherwise
		SetNuiFocus(true, true)
		SetMouseCursorVisibleInMenus(false)

		-- previewPed, not cloned: refreshPreview swaps it. Clothes checked four times a second.
		local lookAt = 0
		while previewActive and previewGen == gen do
			holdFrame()
			if not pedHidden and GetGameTimer() >= lookAt then
				lookAt = GetGameTimer() + 250
				if lookOf(PlayerPedId()) ~= shownLook then refreshPreview(gen) end
			end
			Wait(0)
		end
	end)
end

RegisterNUICallback('setRightPanelMode', function(data, cb)
	cb(1)

	local mode = data and data.mode
	if mode == 'wearables' then
		startWearablesPreview()
	else
		stopWearablesPreview()
	end
end)

-- Hide the pause-menu ped while backpack/armour storage is open.
RegisterNUICallback('setWearablesPedVisible', function(data, cb)
	cb(1)

	local visible = not data or data.visible ~= false
	if not previewActive then return end
	pedHidden = not visible -- no refreshing while it's put away

	SetPauseMenuPedSleepState(visible)
	if not visible then
		SetFrontendActive(false)
	else
		-- Bring the empty frontend + ped back without rebuilding the clone
		SetFrontendActive(true)
		ActivateFrontendMenu(MENU_HASH, false, -1)
		ReplaceHudColourWithRgba(HUD_PAUSE_BG, 0, 0, 0, 0)
		if previewPed and DoesEntityExist(previewPed) then
			GivePedToPauseMenu(previewPed, 2)
			SetPauseMenuPedLighting(true)
			SetPauseMenuPedSleepState(true)
		end
		SetNuiFocus(true, true)
		SetMouseCursorVisibleInMenus(false)
	end
end)

-- Watch slot GPS: keep the minimap on while equipped.
RegisterNetEvent('ox_inventory:wearableEquipped', function(equipped)
	local gpsOn = equipped and equipped.watch == 'gps'
	if GetResourceState('ruck_hud') == 'started' then
		pcall(function()
			exports.ruck_hud:setGPS(gpsOn)
		end)
	end
	TriggerEvent('ruck_hud:setGPS', gpsOn)
end)

return {
	Start = startWearablesPreview,
	Stop = stopWearablesPreview,
	ShouldIgnoreExit = shouldIgnoreExit,
}
