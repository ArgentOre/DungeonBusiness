--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)

-- `strength` scales the party: 1 for a normal party, less for rookies
local function make(rng: Random, strength: number): Types.Party
	local luck = rng:NextNumber(Catalog.party.luckMin, Catalog.party.luckMax)
	local power = math.max(1, math.round(Catalog.party.basePower * luck * strength))
	return {
		power = power,
		hp = power * Catalog.party.hpPerPower,
		strength = strength,
	}
end

return {
	make = make,
}
