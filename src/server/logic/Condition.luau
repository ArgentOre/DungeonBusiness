--!strict
-- A room's condition: the same room at a new condition, or a whole dungeon raised to a floor.
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)

local function withCondition(segment: Types.Segment, condition: number): Types.Segment
	return { kind = segment.kind, condition = condition, mobs = segment.mobs }
end

-- Every room below `floor` is brought up to it; rooms above stay as they are
local function atLeast(dungeon: Types.Dungeon, floor: number): Types.Dungeon
	local segments: { Types.Segment } = {}
	for _, segment in dungeon.segments do
		table.insert(segments, withCondition(segment, math.max(segment.condition, floor)))
	end
	return { segments = segments }
end

return {
	withCondition = withCondition,
	atLeast = atLeast,
}
