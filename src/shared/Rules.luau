--!strict
local Types = require(script.Parent.Types)
local Catalog = require(script.Parent.Catalog)

local function repairCost(segment: Types.Segment, points: number): number
	return points * Catalog.rooms[segment.kind].repairCostPerPoint
end

local function canRepair(state: Types.PlayerState, slot: number, points: number): (boolean, string?)
	local segment = state.dungeon.segments[slot]
	if not segment then
		return false, "No room in that slot"
	end
	if points <= 0 or points ~= math.floor(points) then
		return false, "Repair amount must be a whole number above zero"
	end
	if segment.condition + points > 100 then
		return false, "That's more repair than the room needs"
	end
	if repairCost(segment, points) > state.bronze then
		return false, "Not enough bronze"
	end
	return true
end

local function affordableRepair(state: Types.PlayerState, slot: number): number
	local segment = state.dungeon.segments[slot]
	if not segment then
		return 0
	end
	return math.min(100 - segment.condition, state.bronze // repairCost(segment, 1))
end

local function hasFreeSlot(segment: Types.Segment): boolean
	return #segment.mobs < Catalog.rooms[segment.kind].mobSlots
end

local function canBuyMob(state: Types.PlayerState, slot: number, kind: Types.MobKind): (boolean, string?)
	local segment = state.dungeon.segments[slot]
	if not segment then
		return false, "No room in that slot"
	end
	if not hasFreeSlot(segment) then
		return false, "That room has no free slot"
	end
	local hireCost = Catalog.mobs[kind].hireCost
	if hireCost == nil then
		return false, "That monster can't be hired"
	end
	if hireCost > state.bronze then
		return false, "Not enough bronze"
	end
	return true
end

local function attractsParties(state: Types.PlayerState): boolean
	return state.treasure > 0
end

local function restockCost(amount: number): number
	return amount * Catalog.economy.restockCostPerTreasure
end

local function canRestock(state: Types.PlayerState, amount: number): (boolean, string?)
	if amount <= 0 or amount ~= math.floor(amount) then
		return false, "Restock amount must be a whole number above zero"
	end
	if state.treasure + amount > Catalog.economy.treasureMax then
		return false, "That's more treasure than the room holds"
	end
	if restockCost(amount) > state.bronze then
		return false, "Not enough bronze"
	end
	return true
end

local function affordableRestock(state: Types.PlayerState): number
	return math.min(Catalog.economy.treasureMax - state.treasure, state.bronze // restockCost(1))
end

return {
	attractsParties = attractsParties,
	restockCost = restockCost,
	canRestock = canRestock,
	affordableRestock = affordableRestock,
	repairCost = repairCost,
	canRepair = canRepair,
	affordableRepair = affordableRepair,
	hasFreeSlot = hasFreeSlot,
	canBuyMob = canBuyMob,
}
