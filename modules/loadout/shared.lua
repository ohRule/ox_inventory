if not lib then return end

local Config = lib.load('data.loadouts') or {}
local Kits = Config.kits or {}

---@param list string[]|number[]|false|nil
---@return table<number, true>|false|nil
local function hashModels(list)
	if list == false or not list then return list end

	local set = {}
	for i = 1, #list do
		local model = list[i]
		set[type(model) == 'number' and model or joaat(model)] = true
	end

	return set
end

---@param list string[]|false|nil
---@return table<string, true>|false|nil
local function hashPlates(list)
	if list == false or not list then return list end

	local set = {}
	for i = 1, #list do
		set[(list[i]:gsub('%s+', ''):upper())] = true
	end

	return set
end

local Armouries = Config.armouries or {}

Config.modelSet = hashModels(Config.models)
Config.plateSet = hashPlates(Config.plates)

for i = 1, #Kits do
	local kit = Kits[i]
	kit.modelSet = hashModels(kit.models)
	kit.plateSet = hashPlates(kit.plates)
end

for i = 1, #Armouries do
	local armoury = Armouries[i]
	armoury.modelSet = hashModels(armoury.models)
	armoury.plateSet = hashPlates(armoury.plates)
end

---@param entity number
---@return string
local function vehiclePlate(entity)
	return (GetVehicleNumberPlateText(entity) or ''):gsub('%s+', ''):upper()
end

---True when this kit can be claimed from the targeted vehicle.
---@param kit table
---@param entity number
---@return boolean
local function vehicleAllowed(kit, entity)
	local models = kit.modelSet
	if models == nil then models = Config.modelSet end

	local plates = kit.plateSet
	if plates == nil then plates = Config.plateSet end

	local classes = kit.classes
	if classes == nil then classes = Config.classes end

	if models and models ~= false then
		if not models[GetEntityModel(entity)] then return false end
	end

	if plates and plates ~= false then
		if not plates[vehiclePlate(entity)] then return false end
	end

	-- Class is only used when this kit/config did not set a model list
	if (not models or models == false) and classes and classes ~= false then
		local class = GetVehicleClass(entity)
		local found = false
		for i = 1, #classes do
			if classes[i] == class then
				found = true
				break
			end
		end
		if not found then return false end
	end

	return true
end

---First armoury that matches this vehicle and the player's groups.
---@param entity number
---@param hasGroup fun(groups: table): any
---@return table?
local function getArmoury(entity, hasGroup)
	for i = 1, #Armouries do
		local armoury = Armouries[i]
		if armoury.groups and hasGroup(armoury.groups) and vehicleAllowed(armoury, entity) then
			return armoury
		end
	end
end

return {
	Config = Config,
	Kits = Kits,
	Armouries = Armouries,
	vehicleAllowed = vehicleAllowed,
	vehiclePlate = vehiclePlate,
	getArmoury = getArmoury,
}
