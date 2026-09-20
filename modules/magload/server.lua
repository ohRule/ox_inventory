if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items = require 'modules.items.server'
local Config = lib.load('data.magload') or {}

CreateThread(function()
	while not shared.ready do Wait(50) end

	for name, recipe in pairs(Config) do
		if type(recipe) == 'table' and recipe.give and recipe.bullets then
			local item = Items(name)
			if not item then
				warn(('mag load "%s" is missing from the item list'):format(name))
			elseif not Items(recipe.bullets) or not Items(recipe.give) then
				warn(('mag load "%s" has an invalid bullet/result item'):format(name))
			else
				item.ammo = nil
				item.consume = 1
				item.allowArmed = true

				item.cb = function(event, _, inventory, slot)
					if event == 'usingItem' then
						if Inventory.GetItemCount(inventory, recipe.bullets) < recipe.count then
							TriggerClientEvent('ox_lib:notify', inventory.id, {
								type = 'error',
								description = locale('item_not_enough', Items(recipe.bullets).label),
							})
							return false
						end

						local canFit = Inventory.CanCarryItem(inventory, recipe.give, 1)
						local emptyingSlot = inventory.items[slot]
						if not canFit and emptyingSlot and emptyingSlot.count == 1 then
							canFit = true
						end

						if not canFit then
							TriggerClientEvent('ox_lib:notify', inventory.id, {
								type = 'error',
								description = locale('cannot_carry'),
							})
							return false
						end
					elseif event == 'usedItem' then
						-- Empty mag was already consumed; take the rounds and give a loaded mag
						if Inventory.RemoveItem(inventory, recipe.bullets, recipe.count) then
							Inventory.AddItem(inventory, recipe.give, 1)
						end
					end
				end
			end
		end
	end
end)
