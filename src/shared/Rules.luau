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

return {
	repairCost = repairCost,
	canRepair = canRepair,
	affordableRepair = affordableRepair,
}
