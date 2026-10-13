if not lib then return end

local Inventory = require 'modules.inventory.server'
local Config = lib.load('data.attachments') or {}

---Build the body-prop list other clients should render for this player.
local function buildPayload(inv)
	if not inv or not inv.items then return {} end

	local payload = {}

	for _, slot in pairs(inv.items) do
		local name = slot and slot.name
		if name and Config[name] and not payload[name] then
			local meta = slot.metadata or {}
			payload[name] = {
				components = meta.components or nil,
				specialAmmo = meta.specialAmmo or nil,
				tint = meta.tint or nil,
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
