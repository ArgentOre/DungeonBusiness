--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)

local function powerFor(luck: number, strength: number): number
	return math.max(1, math.round(Catalog.party.basePower * luck * strength))
end

-- `strength` scales the party: 1 for a normal party, less for rookies
local function make(rng: Random, strength: number): Types.Party
	local luck = rng:NextNumber(Catalog.party.luckMin, Catalog.party.luckMax)
	return {
		power = powerFor(luck, strength),
		strength = strength,
	}
end

-- A party of this strength with no luck either way
local function typicalPower(strength: number): number
	return powerFor(1, strength)
end

return {
	make = make,
	typicalPower = typicalPower,
}
