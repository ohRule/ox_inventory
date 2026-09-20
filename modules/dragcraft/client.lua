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

local function addRecipe(id, recipe, sync)
	recipe.server = nil
	RECIPES[id] = recipe

	if sync then return end

	lib.callback.await('dragCraft:server:addRecipe', false, id, recipe, true)
end

lib.callback.register('dragCraft:client:addRecipe', addRecipe)
exports('addRecipe', addRecipe)
