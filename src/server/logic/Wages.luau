--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)

local function due(dungeon: Types.Dungeon): number
	local total = 0
	for _, segment in dungeon.segments do
		for _, mob in segment.mobs do
			total += Catalog.mobs[mob.kind].wage
		end
	end
	return total
end

local function pay(bronze: number, dungeon: Types.Dungeon): number
	return math.max(0, bronze - due(dungeon))
end

return {
	due = due,
	pay = pay,
}