--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Rules = require(Shared.Rules)
local Condition = require(script.Parent.Condition)

local function apply(state: Types.PlayerState, slot: number, points: number): Types.PlayerState
	local segment = state.dungeon.segments[slot]
	local segments = table.clone(state.dungeon.segments)
	segments[slot] = Condition.withCondition(segment, segment.condition + points)
	local after = table.clone(state)
	after.bronze -= Rules.repairCost(segment, points)
	after.dungeon = { segments = segments }
	return after
end

return {
	apply = apply,
}