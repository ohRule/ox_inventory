if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items = require 'modules.items.server'
local Config = lib.load('data.ammoboxes') or {}

-- Attach use callbacks once item list is ready
CreateThread(function()
	while not shared.ready do Wait(50) end

	for name, box in pairs(Config) do
		if type(box) == 'table' and box.give then
			local item = Items(name)
			if not item then
				warn(('ammo box "%s" is missing from the item list'):format(name))
			elseif not Items(box.give) then
				warn(('ammo box "%s" gives unknown item "%s"'):format(name, box.give))
			else
				item.cb = function(event, _, inventory)
					if event == 'usingItem' then
						-- Fail before the progress bar if the rounds will not fit
						if not Inventory.CanCarryItem(inventory, box.give, box.count) then
							TriggerClientEvent('ox_lib:notify', inventory.id, {
								type = 'error',
								description = locale('cannot_carry'),
							})
							return false
						end
					elseif event == 'usedItem' then
						Inventory.AddItem(inventory, box.give, box.count)
					end
				end
			end
		end
	end
end)
