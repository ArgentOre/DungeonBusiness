--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)

local function mobPower(mob: Types.Mob): number
	local stats = Catalog.mobs[mob.kind]
	return stats.damage + stats.maxHp * Catalog.party.mobHpWeight
end

local function segmentPower(segment: Types.Segment): number
	local power = Catalog.rooms[segment.kind].trapDamage
	for _, mob in segment.mobs do
		power += mobPower(mob)
	end
	return power
end

local function dungeonPower(dungeon: Types.Dungeon): number
	local power = 0
	for _, segment in dungeon.segments do
		power += segmentPower(segment)
	end
	return power
end

-- `strength` scales the party: 1 for a normal party, less for rookies
local function make(dungeon: Types.Dungeon, rng: Random, strength: number): Types.Party
	local spread = rng:NextNumber(Catalog.party.powerSpreadMin, Catalog.party.powerSpreadMax)
	local power = math.max(1, math.round(dungeonPower(dungeon) * spread * strength))
	return {
		power = power,
		hp = power * Catalog.party.hpPerPower,
		strength = strength,
	}
end

return {
	dungeonPower = dungeonPower,
	make = make,
}