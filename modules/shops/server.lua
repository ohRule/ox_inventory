if not lib then return end

local Items = require 'modules.items.server'
local Inventory = require 'modules.inventory.server'
local TriggerEventHooks = require 'modules.hooks.server'
local Shops = {}
local locations = shared.target and 'targets' or 'locations'

---@class OxShopItem
---@field slot number
---@field weight number

local function setupShopItems(id, shopType, shopName, groups)
	local shop = id and Shops[shopType][id] or Shops[shopType] --[[@as OxShop]]

	for i = 1, shop.slots do
		local slot = shop.items[i]

		if slot.grade and not groups then
			print(('^1attempted to restrict slot %s (%s) to grade %s, but %s has no job restriction^0'):format(id, slot.name, json.encode(slot.grade), shopName))
			slot.grade = nil
		end

		local Item = Items(slot.name)

		if Item then
			---@type OxShopItem
			slot = {
				name = Item.name,
				slot = i,
				weight = Item.weight,
				count = slot.count,
				price = (server.randomprices and (not slot.currency or slot.currency == 'money')) and (math.ceil(slot.price * (math.random(80, 120)/100))) or slot.price or 0,
				metadata = slot.metadata,
				license = slot.license,
				currency = slot.currency,
				grade = slot.grade
			}

			if slot.metadata then
				slot.weight = Inventory.SlotWeight(Item, slot, true)
			end

			shop.items[i] = slot
		end
	end
end

---@param shopType string
---@param properties OxShop
local function registerShopType(shopType, properties)
	local shopLocations = properties[locations] or properties.locations

	if shopLocations then
		Shops[shopType] = properties
	else
		Shops[shopType] = {
			label = properties.name,
			id = shopType,
			groups = properties.groups or properties.jobs,
			items = properties.inventory,
			slots = #properties.inventory,
			type = 'shop',
		}

		setupShopItems(nil, shopType, properties.name, properties.groups or properties.jobs)
	end
end

---@param shopType string
---@param id number
local function createShop(shopType, id)
	local shop = Shops[shopType]

	if not shop then return end

	local store = (shop[locations] or shop.locations)?[id]

	if not store then return end

	local groups = shop.groups or shop.jobs
    local coords

    if shared.target then
        if store.length then
            local z = store.loc.z + math.abs(store.minZ - store.maxZ) / 2
            coords = vec3(store.loc.x, store.loc.y, z)
        else
            coords = store.coords or store.loc
        end
    else
        coords = store
    end

	shop[id] = {
		label = shop.name,
		id = shopType..' '..id,
		groups = groups,
		items = table.clone(shop.inventory),
		slots = #shop.inventory,
		type = 'shop',
		coords = coords,
		distance = shared.target and shop.targets?[id]?.distance,
	}

	setupShopItems(id, shopType, shop.name, groups)

	return shop[id]
end

for shopType, shopDetails in pairs(lib.load('data.shops') or {}) do
	registerShopType(shopType, shopDetails)
end

---@param shopType string
---@param shopDetails OxShop
exports('RegisterShop', function(shopType, shopDetails)
	registerShopType(shopType, shopDetails)
end)

lib.callback.register('ox_inventory:openShop', function(source, data)
	local playerInv, shop = Inventory(source)

	if not playerInv then return end

	if data then
		shop = Shops[data.type]

		if not shop then return end

		if not shop.items then
			shop = (data.id and shop[data.id] or createShop(data.type, data.id))

			if not shop then return end
		end

		---@cast shop OxShop

		if shop.groups then
			local group = server.hasGroup(playerInv, shop.groups)
			if not group then return end
		end

		if type(shop.coords) == 'vector3' and #(GetEntityCoords(GetPlayerPed(source)) - shop.coords) > 10 then
			return
		end

		local shopType, shopId = shop.id:match('^(.-) (%d+)$')

        local hookPayload = {
            source = source,
            shopId = shopId or shop.id,
			shopType = shopType or shop.id,
            label = shop.label,
            slots = shop.slots,
            items = shop.items,
            groups = shop.groups,
            coords = shop.coords,
            distance = shop.distance
        }

        local hooks <close> = TriggerEventHooks('openShop', hookPayload)

		if not hooks.success then return end

		---@diagnostic disable-next-line: assign-type-mismatch
		playerInv:openInventory(playerInv)
		playerInv.currentShop = shop.id
	end

	return { label = playerInv.label, type = playerInv.type, slots = playerInv.slots, weight = playerInv.weight, maxWeight = playerInv.maxWeight }, shop
end)

local function canAffordItem(inv, currency, price)
	local canAfford = price >= 0 and Inventory.GetItemCount(inv, currency) >= price

	return canAfford or {
		type = 'error',
		description = locale('cannot_afford', ('%s%s'):format((currency == 'money' and locale('$') or math.groupdigits(price)), (currency == 'money' and math.groupdigits(price) or ' '..Items(currency).label)))
	}
end

local function removeCurrency(inv, currency, price)
	Inventory.RemoveItem(inv, currency, price)
end

local function isRequiredGrade(grade, rank)
	if type(grade) == "table" then
		for i=1, #grade do
			if grade[i] == rank then
				return true
			end
		end
		return false
	else
		return rank >= grade
	end
end

lib.callback.register('ox_inventory:buyItem', function(source, data)
	if data.toType == 'player' then
		data.count = math.max(1, math.floor(data.count or 1))

		local playerInv = Inventory(source)

		if not playerInv or not playerInv.currentShop then return end

		local shopType, shopId = playerInv.currentShop:match('^(.-) (%d-)$')

		if not shopType then shopType = playerInv.currentShop end

		if shopId then shopId = tonumber(shopId) end

		local shop = shopId and Shops[shopType][shopId] or Shops[shopType]
		local fromData = shop.items[data.fromSlot]
		local toData = playerInv.items[data.toSlot]

		if fromData then
			if fromData.count then
				if fromData.count < 1 then
					return false, false, { type = 'error', description = locale('shop_nostock') }
				elseif data.count > fromData.count then
					data.count = fromData.count
				end
			end

			if fromData.license and server.hasLicense and not server.hasLicense(playerInv, fromData.license) then
				return false, false, { type = 'error', description = locale('item_unlicensed') }
			end

			if fromData.grade then
				local _, rank = server.hasGroup(playerInv, shop.groups)
				if not isRequiredGrade(fromData.grade, rank) then
					return false, false, { type = 'error', description = locale('stash_lowgrade') }
				end
			end

			local currency = fromData.currency or 'money'
			local fromItem = Items(fromData.name)

			local result = fromItem.cb and fromItem.cb('buying', fromItem, playerInv, data.fromSlot, shop)
			if result == false then return false end

			local toItem = toData and Items(toData.name)

			local metadata, count = Items.Metadata(playerInv, fromItem, fromData.metadata and table.clone(fromData.metadata) or {}, data.count)
			local price = count * fromData.price

			if toData == nil or (fromItem.name == toItem?.name and fromItem.stack and table.matches(toData.metadata, metadata)) then
				local newWeight = playerInv.weight + (fromItem.weight + (metadata?.weight or 0)) * count

				if newWeight > playerInv.maxWeight then
					return false, false, { type = 'error', description = locale('cannot_carry') }
				end

				local canAfford = canAffordItem(playerInv, currency, price)

				if canAfford ~= true then
					return false, false, canAfford
				end

				if fromData.count then
					fromData.count -= count
				end

				local hooks <close> = TriggerEventHooks('buyItem', {
					source = source,
					shopType = shopType,
					shopId = shopId,
					toInventory = playerInv.id,
					toSlot = data.toSlot,
					fromSlot = fromData,
					itemName = fromData.name,
					metadata = metadata,
					count = count,
					price = fromData.price,
					totalPrice = price,
					currency = currency,
				})

				if not hooks.success or not Inventory.SetSlot(playerInv, fromItem, count, metadata, data.toSlot) then
					if fromData.count then
						fromData.count += count
					end

					return false
				end

				playerInv.weight = newWeight
				removeCurrency(playerInv, currency, price)

				if server.syncInventory then server.syncInventory(playerInv) end

				local message = locale('purchased_for', count, metadata?.label or fromItem.label, (currency == 'money' and locale('$') or math.groupdigits(price)), (currency == 'money' and math.groupdigits(price) or ' '..Items(currency).label))

				if server.loglevel > 0 then
					if server.loglevel > 1 or fromData.price >= 500 then
						lib.logger(playerInv.owner, 'buyItem', ('"%s" %s'):format(playerInv.label, message:lower()), ('shop:%s'):format(shop.label))
					end
				end

				return true, {data.toSlot, playerInv.items[data.toSlot], shop.items[data.fromSlot].count and shop.items[data.fromSlot], playerInv.weight}, { type = 'success', description = message }
			end

			return false, false, { type = 'error', description = locale('unable_stack_items') }
		end
	end
end)

---Purchase every cart line atomically (validate all, then apply all).
---@param source number
---@param data { items: { fromSlot: number, count: number }[] }
lib.callback.register('ox_inventory:buyCart', function(source, data)
	local playerInv = Inventory(source)

	if not playerInv or not playerInv.currentShop then return false, false, { type = 'error', description = locale('inventory_right_access') } end
	if type(data) ~= 'table' or type(data.items) ~= 'table' or #data.items < 1 then return false end

	local shopType, shopId = playerInv.currentShop:match('^(.-) (%d-)$')

	if not shopType then shopType = playerInv.currentShop end
	if shopId then shopId = tonumber(shopId) end

	local shop = shopId and Shops[shopType][shopId] or Shops[shopType]
	if not shop then return false end

	-- Merge duplicate fromSlot lines from the client
	local merged = {}
	for i = 1, #data.items do
		local entry = data.items[i]
		local fromSlot = tonumber(entry.fromSlot)
		local count = math.max(1, math.floor(tonumber(entry.count) or 1))

		if fromSlot then
			merged[fromSlot] = (merged[fromSlot] or 0) + count
		end
	end

	local planned = {}
	local currencyCosts = {}
	local totalWeight = playerInv.weight
	-- Simulated slot occupancy so multiple lines don't claim the same empty slot
	local reserved = {}

	for fromSlot, count in pairs(merged) do
		local fromData = shop.items[fromSlot]

		if not fromData then
			return false, false, { type = 'error', description = locale('item_not_enough', 'item') }
		end

		if fromData.count then
			if fromData.count < 1 then
				return false, false, { type = 'error', description = locale('shop_nostock') }
			elseif count > fromData.count then
				count = fromData.count
			end
		else
			count = math.min(count, 99)
		end

		if fromData.license and server.hasLicense and not server.hasLicense(playerInv, fromData.license) then
			return false, false, { type = 'error', description = locale('item_unlicensed') }
		end

		if fromData.grade then
			local _, rank = server.hasGroup(playerInv, shop.groups)
			if not isRequiredGrade(fromData.grade, rank) then
				return false, false, { type = 'error', description = locale('stash_lowgrade') }
			end
		end

		local fromItem = Items(fromData.name)
		if not fromItem then return false end

		local result = fromItem.cb and fromItem.cb('buying', fromItem, playerInv, fromSlot, shop)
		if result == false then return false end

		local metadata
		metadata, count = Items.Metadata(playerInv, fromItem, fromData.metadata and table.clone(fromData.metadata) or {}, count)

		local currency = fromData.currency or 'money'
		local price = count * fromData.price
		currencyCosts[currency] = (currencyCosts[currency] or 0) + price

		local lineWeight = (fromItem.weight + (metadata?.weight or 0)) * count
		totalWeight += lineWeight

		if totalWeight > playerInv.maxWeight then
			return false, false, { type = 'error', description = locale('cannot_carry') }
		end

		-- Resolve destination slot against live inventory + prior reservations
		local toSlot

		if fromItem.stack then
			for slotId = 1, playerInv.slots do
				local sim = reserved[slotId]
				local live = playerInv.items[slotId]

				if sim and sim.name == fromItem.name and table.matches(sim.metadata, metadata) then
					toSlot = slotId
					break
				elseif not sim and live and live.name == fromItem.name and fromItem.stack and table.matches(live.metadata, metadata) then
					toSlot = slotId
					break
				end
			end
		end

		if not toSlot then
			for slotId = 1, playerInv.slots do
				if not reserved[slotId] and not playerInv.items[slotId] then
					toSlot = slotId
					break
				end
			end
		end

		if not toSlot then
			return false, false, { type = 'error', description = locale('cannot_carry') }
		end

		local existing = reserved[toSlot]
		if existing then
			existing.count += count
		else
			reserved[toSlot] = {
				name = fromItem.name,
				metadata = metadata,
				count = (playerInv.items[toSlot]?.count or 0) + count,
			}
		end

		planned[#planned + 1] = {
			fromSlot = fromSlot,
			fromData = fromData,
			fromItem = fromItem,
			metadata = metadata,
			count = count,
			toSlot = toSlot,
			price = price,
			unitPrice = fromData.price,
			currency = currency,
		}
	end

	if #planned < 1 then return false end

	for currency, price in pairs(currencyCosts) do
		local canAfford = canAffordItem(playerInv, currency, price)
		if canAfford ~= true then
			return false, false, canAfford
		end
	end

	local playerUpdates = {}
	local shopUpdates = {}
	local purchasedLabels = {}

	for i = 1, #planned do
		local line = planned[i]
		local fromData = line.fromData

		if fromData.count then
			fromData.count -= line.count
		end

		local hooks <close> = TriggerEventHooks('buyItem', {
			source = source,
			shopType = shopType,
			shopId = shopId,
			toInventory = playerInv.id,
			toSlot = line.toSlot,
			fromSlot = fromData,
			itemName = fromData.name,
			metadata = line.metadata,
			count = line.count,
			price = line.unitPrice,
			totalPrice = line.price,
			currency = line.currency,
		})

		if not hooks.success or not Inventory.SetSlot(playerInv, line.fromItem, line.count, line.metadata, line.toSlot) then
			-- Roll back stock for this line and any already-applied lines
			if fromData.count then
				fromData.count += line.count
			end

			for j = 1, i - 1 do
				local prev = planned[j]
				if prev.fromData.count then
					prev.fromData.count += prev.count
				end
				Inventory.RemoveItem(playerInv, prev.fromItem.name, prev.count, prev.metadata, prev.toSlot)
			end

			return false
		end

		playerUpdates[#playerUpdates + 1] = {
			item = playerInv.items[line.toSlot],
			inventory = playerInv.id
		}

		if fromData.count then
			shopUpdates[#shopUpdates + 1] = {
				item = shop.items[line.fromSlot],
				inventory = 'shop'
			}
		end

		purchasedLabels[#purchasedLabels + 1] = ('%sx %s'):format(line.count, line.metadata?.label or line.fromItem.label)
	end

	-- Weight already updated by SetSlot; only charge currencies here
	for currency, price in pairs(currencyCosts) do
		removeCurrency(playerInv, currency, price)
	end

	if server.syncInventory then server.syncInventory(playerInv) end

	local message
	if #purchasedLabels == 1 then
		local line = planned[1]
		message = locale('purchased_for', line.count, line.metadata?.label or line.fromItem.label, (line.currency == 'money' and locale('$') or math.groupdigits(line.price)), (line.currency == 'money' and math.groupdigits(line.price) or ' '..Items(line.currency).label))
	else
		local currency, price = next(currencyCosts)
		message = locale('purchased_cart', #planned, (currency == 'money' and locale('$') or math.groupdigits(price)), (currency == 'money' and math.groupdigits(price) or ' '..(Items(currency) and Items(currency).label or currency)))
	end

	if server.loglevel > 0 then
		lib.logger(playerInv.owner, 'buyCart', ('"%s" %s'):format(playerInv.label, message:lower()), ('shop:%s'):format(shop.label))
	end

	return true, { playerUpdates, shopUpdates, playerInv.weight }, { type = 'success', description = message }
end)

server.shops = Shops
