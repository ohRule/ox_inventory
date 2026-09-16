if not lib then return end

local Items = require 'modules.items.client'
local Recipes = {}

do
	local data = lib.load('data.quickcraft') or {}

	for i = 1, #data do
		local recipe = data[i]
		local item = Items[recipe.name]

		if item then
			Recipes[i] = {
				id = i,
				name = recipe.name,
				label = recipe.label or item.label,
				category = recipe.category or 'tools',
				ingredients = recipe.ingredients or {},
				duration = recipe.duration or 3000,
				count = type(recipe.count) == 'number' and recipe.count or 1,
			}
		else
			warn(('failed to setup quickcraft recipe #%s - item "%s" does not exist'):format(i, recipe.name))
		end
	end
end

---Recipes for the NUI quick-craft panel
---@return table
local function getRecipes()
	return Recipes
end

---Client-side progress for quick craft (no crafting bench required)
lib.callback.register('ox_inventory:startQuickCraft', function(recipeId)
	local recipe = Recipes[recipeId]
	if not recipe then return false end

	local item = Items[recipe.name]

	return lib.progressCircle({
		label = locale('crafting_item', recipe.label or item?.label or recipe.name),
		duration = recipe.duration or 3000,
		canCancel = true,
		disable = {
			move = true,
			combat = true,
		},
		anim = {
			dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
			clip = 'machinic_loop_mechandplayer',
		},
	})
end)

return {
	GetRecipes = getRecipes,
}
