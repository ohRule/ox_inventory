if not lib then return end

local Inventory = require 'modules.inventory.client'
local Config = lib.load('data.magload') or {}

local function isRecipe(entry)
	return type(entry) == 'table' and entry.give and entry.bullets
end

local function shouldChain(name)
	local recipe = Config[name]
	if not isRecipe(recipe) then return false end
	if recipe.chain ~= nil then return recipe.chain end
	return Config.chain ~= false
end

AddEventHandler('ox_inventory:usedItem', function(name)
	if not shouldChain(name) then return end

	local recipe = Config[name]

	CreateThread(function()
		Wait(600)
		if Inventory.GetItemCount(recipe.bullets) < recipe.count then return end
		local slot = Inventory.GetSlotIdWithItem(name)
		if slot then
			exports.ox_inventory:useSlot(slot)
		end
	end)
end)
