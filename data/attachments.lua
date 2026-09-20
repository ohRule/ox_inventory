-- Props attached to the ped while the item is in inventory.
-- Weapons hide when actually in-hand; they stay on the body in vehicles.
-- Weapon props use the item's metadata (suppressor, mag, flashlight, tint).
--
-- bone: GTA bone index (number) or bone name (string)
-- pos / rot: offset from that bone
-- model: optional prop hash/name; weapons default to GetWeapontypeModel
-- hideWhenEquipped: default true for WEAPON_* items
-- hideInVehicle: optional; default false (keep props visible in cars)

return {
	['WEAPON_ASSAULTRIFLE'] = {
		bone = 24818, -- SKEL_Spine3 (upper back)
		pos = vec3(0.09, -0.16, 0.02),
		rot = vec3(0.0, 165.0, 0.0),
	},
	['WEAPON_CARBINERIFLE'] = {
		bone = 24818,
		pos = vec3(0.09, -0.16, 0.02),
		rot = vec3(0.0, 165.0, 0.0),
	},
	['WEAPON_PISTOL'] = {
		bone = 51826, -- SKEL_R_Thigh
		pos = vec3(0.02, 0.03, 0.18),
		rot = vec3(-90.0, 0.0, 0.0),
	},
}
