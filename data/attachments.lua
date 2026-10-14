-- Props attached to the ped while the item is in inventory.
-- Synced via player state (ox_attachments) so other players see them too.
-- Weapons hide when actually in-hand; they stay on the body in vehicles.
-- Weapon props use the item's metadata (suppressor, mag, flashlight, tint).
--
-- bone: GTA bone index (number) or bone name (string)
-- pos / rot: offset from that bone
-- model: optional prop hash/name; weapons default to GetWeapontypeModel
-- hideWhenEquipped: default true for WEAPON_* items
-- hideInVehicle: optional; default false (keep props visible in cars). When true, hidden in a
--   vehicle, but not on a motorcycle, cycle or boat
-- spots: optional; other places on the same bone (vec3s), tried in order when its own place
--   is taken by an item in an earlier slot; with none free it isn't shown
-- hideWithHolster: optional; not shown while a holster is in its Wearables slot (for pistols,
--   when the holster shows the pistol)

return {
	['WEAPON_SPECIALCARBINE_MK2'] = {
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
