---@diagnostic disable: missing-return

-- Drop one item onto another in your inventory to craft.
-- Recipe key is "itemA itemB" (order does not matter).
--
-- costs: items consumed (need = count, remove = take them)
-- result: items given on success
-- duration / label / anim: progress bar

---@class CraftRecipe
---@field duration number
---@field label? string
---@field client? CallbackFunc
---@field server? CallbackFunc
---@field result ItemResult[]
---@field costs table<string, CraftCost>
---@field anim? { dict: string, clip: string }

---@class CallbackFunc
---@field before fun(recipeData: CraftRecipe):boolean
---@field after fun(recipeData: CraftRecipe):boolean

---@class ItemResult
---@field name string
---@field amount? number
---@field min? number
---@field max? number

---@class CraftCost
---@field need number
---@field remove boolean

local function magRecipe(emptyMag, bullets, bulletCount, loadedMag, label)
	return {
		duration = 2000,
		label = label or 'Loading ammunition...',
		costs = {
			[emptyMag] = { need = 1, remove = true },
			[bullets] = { need = bulletCount, remove = true },
		},
		result = {
			{ name = loadedMag, amount = 1 },
		},
		anim = {
			dict = 'amb@prop_human_parking_meter@male@base',
			clip = 'base',
		},
	}
end

---@type table<string, CraftRecipe>
return {
	['bullet-rifle empty_rifle_magazine'] = magRecipe('empty_rifle_magazine', 'bullet-rifle', 30, 'ammo-rifle', 'Loading 5.56 magazine...'),
	['bullet-rifle2 empty_rifle2_magazine'] = magRecipe('empty_rifle2_magazine', 'bullet-rifle2', 30, 'ammo-rifle2', 'Loading 7.62 magazine...'),
	['bullet-9 empty_9_magazine'] = magRecipe('empty_9_magazine', 'bullet-9', 17, 'ammo-9', 'Loading 9mm magazine...'),
	['bullet-45 empty_45_magazine'] = magRecipe('empty_45_magazine', 'bullet-45', 18, 'ammo-45', 'Loading .45 magazine...'),
	['bullet-44 empty_44_magazine'] = magRecipe('empty_44_magazine', 'bullet-44', 6, 'ammo-44', 'Loading .44 magazine...'),
	['bullet-38 empty_38_magazine'] = magRecipe('empty_38_magazine', 'bullet-38', 7, 'ammo-38', 'Loading .38 magazine...'),
	['bullet-22 empty_22_magazine'] = magRecipe('empty_22_magazine', 'bullet-22', 10, 'ammo-22', 'Loading .22 magazine...'),
	['bullet-50 empty_50_magazine'] = magRecipe('empty_50_magazine', 'bullet-50', 9, 'ammo-50', 'Loading .50 AE magazine...'),
	['bullet-sniper empty_sniper_magazine'] = magRecipe('empty_sniper_magazine', 'bullet-sniper', 10, 'ammo-sniper', 'Loading 7.62x51 magazine...'),
	['bullet-heavysniper empty_heavysniper_magazine'] = magRecipe('empty_heavysniper_magazine', 'bullet-heavysniper', 6, 'ammo-heavysniper', 'Loading .50 BMG magazine...'),
	['bullet-shotgun empty_shotgun_shell'] = magRecipe('empty_shotgun_shell', 'bullet-shotgun', 1, 'ammo-shotgun', 'Reloading 12 gauge shell...'),
}
