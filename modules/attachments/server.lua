if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items = require 'modules.items.server'
local Config = lib.load('data.attachments') or {}

-- A holster in a Wearables slot (after the pockets): it shows the pistol itself, so
-- entries marked hideWithHolster stay off the body.
local function holsterWorn(inv)
	for slot, item in pairs(inv.items) do
		if slot > shared.playerslots and item.name then
			local data = Items(item.name)
			if data and data.wearable == 'holster' then return true end
		end
	end
	return false
end

---Build the body-prop list other clients should render for this player. One per item
---name, from its lowest slot (`slot` orders who gets a shared spot, client side).
local function buildPayload(inv)
	if not inv or not inv.items then return {} end

	local payload = {}
	local holster = holsterWorn(inv)

	for _, slot in pairs(inv.items) do
		local name = slot and slot.name
		local cfg = name and Config[name]
		if cfg and not (holster and cfg.hideWithHolster) and (not payload[name] or slot.slot < payload[name].slot) then
			local meta = slot.metadata or {}
			payload[name] = {
				components = meta.components or nil,
				specialAmmo = meta.specialAmmo or nil,
				tint = meta.tint or nil,
				slot = slot.slot,
			}
		end
	end

	return payload
end

local function sync(inv)
	inv = Inventory(inv)
	if not inv or not inv.player then return end

	local player = Player(inv.id)
	if not player then return end

	player.state:set('ox_attachments', buildPayload(inv), true)
end

AddEventHandler('playerDropped', function()
	-- State bag is cleared with the player; nothing to wipe here.
end)

return {
	sync = sync,
	buildPayload = buildPayload,
}
