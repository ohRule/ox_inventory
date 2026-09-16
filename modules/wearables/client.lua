if not lib then return end

local Utils = require 'modules.utils.client'

local previewCam
local previewActive = false
local savedBlur = false

---Place a scripted cam so the ped sits in the open wearables preview area (right side)
local function updatePreviewCam()
	if not previewCam then return end

	local ped = cache.ped
	local coords = GetEntityCoords(ped)
	-- Offset slightly left of the ped's forward so they read on the right half of the screen
	local camCoords = GetOffsetFromEntityInWorldCoords(ped, -0.55, 2.35, 0.45)

	SetCamCoord(previewCam, camCoords.x, camCoords.y, camCoords.z)
	PointCamAtCoord(previewCam, coords.x, coords.y, coords.z + 0.35)
end

local function stopWearablesPreview()
	if not previewActive then return end

	previewActive = false

	if previewCam then
		RenderScriptCams(false, true, 250, true, false)
		DestroyCam(previewCam, false)
		previewCam = nil
	end

	-- Restore inventory blur if it was on before wearables opened
	if savedBlur and client.screenblur then
		Utils.blurIn()
	end
	savedBlur = false
end

local function startWearablesPreview()
	if previewActive then
		updatePreviewCam()
		return
	end

	previewActive = true
	savedBlur = client.screenblur == true

	-- Blur hides the ped; clear it while previewing
	if client.screenblur then
		Utils.blurOut()
	end

	local ped = cache.ped
	local coords = GetEntityCoords(ped)
	local camCoords = GetOffsetFromEntityInWorldCoords(ped, -0.55, 2.35, 0.45)

	previewCam = CreateCamWithParams(
		'DEFAULT_SCRIPTED_CAMERA',
		camCoords.x, camCoords.y, camCoords.z,
		0.0, 0.0, 0.0,
		42.0,
		false,
		0
	)

	PointCamAtCoord(previewCam, coords.x, coords.y, coords.z + 0.35)
	SetCamActive(previewCam, true)
	RenderScriptCams(true, true, 300, true, false)

	CreateThread(function()
		while previewActive do
			updatePreviewCam()
			-- Keep the ped still-ish for a cleaner preview
			DisableControlAction(0, 30, true)
			DisableControlAction(0, 31, true)
			DisableControlAction(0, 21, true)
			DisableControlAction(0, 22, true)
			Wait(0)
		end
	end)
end

---NUI tells us which right-panel tab is active
RegisterNUICallback('setRightPanelMode', function(data, cb)
	cb(1)

	local mode = data and data.mode
	if mode == 'wearables' then
		startWearablesPreview()
	else
		stopWearablesPreview()
	end
end)

return {
	Start = startWearablesPreview,
	Stop = stopWearablesPreview,
}
