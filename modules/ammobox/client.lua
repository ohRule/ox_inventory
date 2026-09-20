if not lib then return end

local Inventory = require 'modules.inventory.client'
local Config = lib.load('data.ammoboxes') or {}

local function isBox(entry)
	return type(entry) == 'table' and entry.give and entry.count
end

local function shouldChain(name)
	local box = Config[name]
	if not isBox(box) then return false end
	if box.chain ~= nil then return box.chain end
	return Config.chain ~= false
end

-- After one box finishes, start the next of the same type (if chain is on)
AddEventHandler('ox_inventory:usedItem', function(name)
	if not shouldChain(name) then return end

	CreateThread(function()
		Wait(600)
		local slot = Inventory.GetSlotIdWithItem(name)
		if slot then
			exports.ox_inventory:useSlot(slot)
		end
	end)
end)
