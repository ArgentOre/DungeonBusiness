--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)

local function buildSegment(starter: Types.StarterSegment): Types.Segment
	local mobs: { Types.Mob } = {}
	for _, kind: Types.MobKind in starter.mobs do
		local mob: Types.Mob = { kind = kind }
		table.insert(mobs, mob)
	end
	return { kind = starter.kind, condition = 100, mobs = mobs }
end

local function create(): Types.PlayerState
	local segments: { Types.Segment } = {}
	for _, starter in Catalog.starterLayout do
		table.insert(segments, buildSegment(starter))
	end
	return {
		bronze = Catalog.economy.startingBronze,
		treasure = Catalog.economy.treasureStart,
		spoils = 0,
		reputation = 0,
		dungeon = { segments = segments },
	}
end

return {
	create = create,
}