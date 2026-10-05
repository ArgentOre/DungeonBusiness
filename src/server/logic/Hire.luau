--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)

local function apply(state: Types.PlayerState, slot: number, kind: Types.MobKind): Types.PlayerState
	local hireCost = Catalog.mobs[kind].hireCost
	assert(hireCost, "Check Rules.canBuyMob before Hire.apply")
	local segment = state.dungeon.segments[slot]
	local mobs = table.clone(segment.mobs)
	local hired: Types.Mob = { kind = kind }
	table.insert(mobs, hired)
	local segments = table.clone(state.dungeon.segments)
	segments[slot] = { kind = segment.kind, condition = segment.condition, mobs = mobs }
	return {
		bronze = state.bronze - hireCost,
		dungeon = { segments = segments },
	}
end

return {
	apply = apply,
}
