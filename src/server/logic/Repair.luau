--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Rules = require(Shared.Rules)

local function apply(state: Types.PlayerState, slot: number, points: number): Types.PlayerState
	local segment = state.dungeon.segments[slot]
	local segments = table.clone(state.dungeon.segments)
	segments[slot] = { kind = segment.kind, condition = segment.condition + points, mobs = segment.mobs }
	return {
		bronze = state.bronze - Rules.repairCost(segment, points),
		treasure = state.treasure,
		spoils = state.spoils,
		reputation = state.reputation,
		dungeon = { segments = segments },
	}
end

return {
	apply = apply,
}