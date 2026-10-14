if not lib then return end

local RECIPES = require 'data.dragcraft'

RegisterNetEvent('dragCraft:Craft', function(duration, index)
	local recipe = RECIPES[index]
	if not recipe then
		lib.notify({ type = 'error', description = 'Unknown craft recipe' })
		TriggerServerEvent('dragCraft:success', false, index)
		return
	end

	TriggerServerEvent('ox_inventory:closeInventory')

	local continue

	if recipe.client?.before then
		continue = recipe.client.before(recipe)
	end

	if continue == false then return end

	local result = lib.progressCircle({
		duration = duration,
		label = recipe.label or 'Crafting...',
		position = 'middle',
		useWhileDead = false,
		canCancel = true,
		disable = {
			car = true,
		},
		anim = recipe.anim,
	})

	TriggerServerEvent('dragCraft:success', result, index)

	if result and recipe.client?.after then
		recipe.client.after(recipe)
	end
end)

-- Recipes are added on the server (exports.ox_inventory:addRecipe there), which sends them
-- here. One added from this side only shows locally: the server must never take a recipe
-- from a client, or a modified client could add one that gives anything.
local function addRecipe(id, recipe)
	recipe.server = nil
	RECIPES[id] = recipe
end

lib.callback.register('dragCraft:client:addRecipe', addRecipe)
exports('addRecipe', addRecipe)
