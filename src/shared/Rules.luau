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

-- Junk never runs out, so parties always come; with no real treasure only rookies do
local function onlyJunk(state: Types.PlayerState): boolean
	return state.treasure <= 0
end

-- How strongly the treasure draws visitors, 0 (only junk) to 1 (a full treasure room).
-- More treasure brings stronger parties carrying better gear.
local function lure(state: Types.PlayerState): number
	return math.clamp(state.treasure / Catalog.economy.treasureMax, 0, 1)
end

local function isWholeAmount(amount: number): boolean
	return amount > 0 and amount == math.floor(amount)
end

local function canSell(state: Types.PlayerState, amount: number): (boolean, string?)
	if not isWholeAmount(amount) then
		return false, "Amount must be a whole number above zero"
	end
	if amount > state.spoils then
		return false, "Not that many spoils"
	end
	return true
end

local function stockable(state: Types.PlayerState): number
	return math.min(state.spoils, Catalog.economy.treasureMax - state.treasure)
end

local function canStock(state: Types.PlayerState, amount: number): (boolean, string?)
	if not isWholeAmount(amount) then
		return false, "Amount must be a whole number above zero"
	end
	if amount > state.spoils then
		return false, "Not that many spoils"
	end
	if state.treasure + amount > Catalog.economy.treasureMax then
		return false, "That's more treasure than the room holds"
	end
	return true
end

return {
	onlyJunk = onlyJunk,
	lure = lure,
	canSell = canSell,
	stockable = stockable,
	canStock = canStock,
	repairCost = repairCost,
	canRepair = canRepair,
	affordableRepair = affordableRepair,
	hasFreeSlot = hasFreeSlot,
	canBuyMob = canBuyMob,
}
