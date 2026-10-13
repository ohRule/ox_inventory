if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items = require 'modules.items.server'
local SLOT_IDS = require 'modules.wearables.shared'

local function bagLimit(inv)
	return inv.bagSlots or inv.slots
end

local function zoneFor(inv, slot)
	if not inv or inv.type ~= 'player' then return end
	local bag = bagLimit(inv)
	if not slot or slot <= bag then return end
	return SLOT_IDS[slot - bag]
end

local function apply(inv)
	if not inv or inv.type ~= 'player' then return end

	if not inv.bagSlots then
		inv.bagSlots = inv.slots
	end

	local want = inv.bagSlots + #SLOT_IDS
	if inv.slots < want then
		Inventory.SetSlotCount(inv, want)
	end
end

local function allowMove(fromInv, toInv, fromSlot, toSlot)
	local incoming = fromInv.items[fromSlot]
	if toInv and zoneFor(toInv, toSlot) then
		local zone = zoneFor(toInv, toSlot)
		local item = incoming and Items(incoming.name)
		if not item or item.wearable ~= zone then return false end
	end

	-- Swap puts the destination item back into fromSlot.
	if fromInv and zoneFor(fromInv, fromSlot) then
		local dest = toInv and toInv.items[toSlot]
		if dest then
			local zone = zoneFor(fromInv, fromSlot)
			local item = Items(dest.name)
			if not item or item.wearable ~= zone then return false end
		end
	end

	return true
end

local function touches(inv, slot)
	return zoneFor(inv, slot) ~= nil
end

-- Watch GPS stays on while equipped; HUD toggle is skipped.
local function syncEquipped(inv)
	if not inv or not inv.player then return end

	local bag = bagLimit(inv)
	local equipped = {}

	for i = 1, #SLOT_IDS do
		local slot = inv.items[bag + i]
		equipped[SLOT_IDS[i]] = slot and slot.name or false
	end

	TriggerClientEvent('ox_inventory:wearableEquipped', inv.id, equipped)
end

return {
	apply = apply,
	allowMove = allowMove,
	touches = touches,
	syncEquipped = syncEquipped,
	ids = SLOT_IDS,
}
