--!strict
-- What the administrator can see coming: the strongest party the dungeon stops as it
-- stands now, and how strong the next parties will typically be.
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local PartyGen = require(script.Parent.PartyGen)
local PlayRaid = require(script.Parent.PlayRaid)
local RaidSim = require(script.Parent.RaidSim)

-- Raids are deterministic and a stronger party never does worse, so the first power
-- that escapes marks the line. The search always ends: a strong enough party knocks out
-- every monster in one hit and outlasts every trap.
local function strongestHeld(dungeon: Types.Dungeon): number
	local power = 1
	while RaidSim.simulate(dungeon, { power = power, strength = 1 }).won do
		power += 1
	end
	return power - 1
end

local function of(state: Types.PlayerState): Types.Outlook
	return {
		holds = strongestHeld(state.dungeon),
		coming = PartyGen.typicalPower(PlayRaid.nextPartyStrength(state)),
	}
end

return {
	of = of,
}
