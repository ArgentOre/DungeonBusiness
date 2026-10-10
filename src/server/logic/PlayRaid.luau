--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)
local Rules = require(Shared.Rules)
local PartyGen = require(script.Parent.PartyGen)
local RaidSim = require(script.Parent.RaidSim)
local Spoils = require(script.Parent.Spoils)
local Wages = require(script.Parent.Wages)

-- A party that escapes carries some of the stocked treasure away with it
local function treasureAfter(treasure: number, won: boolean): number
	if won then
		return treasure
	end
	return math.max(0, treasure - Catalog.economy.treasureTakenPerEscape)
end

-- The safety net: monsters patch the worst damage themselves, for free
local function staffPatch(dungeon: Types.Dungeon): Types.Dungeon
	local floor = Catalog.economy.staffPatchFloor
	local segments: { Types.Segment } = {}
	for _, segment in dungeon.segments do
		table.insert(segments, { kind = segment.kind, condition = math.max(segment.condition, floor), mobs = segment.mobs })
	end
	return { segments = segments }
end

-- From rookie strength (lure 0) to full strength (lure 1)
local function partyStrength(lure: number): number
	local rookie = Catalog.party.rookieStrength
	return rookie + (1 - rookie) * lure
end

-- Word spreads: every raid held in a row draws a slightly stronger party
local function fame(reputation: number): number
	return 1 + Catalog.party.reputationStep * reputation
end

-- An escape proves the dungeon can be beaten, so its reputation starts over
local function reputationAfter(reputation: number, won: boolean): number
	if won then
		return math.min(Catalog.party.reputationMax, reputation + 1)
	end
	return 0
end

local function play(state: Types.PlayerState, rng: Random): (Types.PlayerState, Types.RaidResult)
	local lure = Rules.lure(state)
	local party = PartyGen.make(rng, partyStrength(lure) * fame(state.reputation))
	local result = RaidSim.simulate(state.dungeon, party)
	return {
		bronze = Wages.pay(state.bronze, result.after),
		treasure = treasureAfter(state.treasure, result.won),
		spoils = state.spoils + Spoils.dropped(result, lure),
		reputation = reputationAfter(state.reputation, result.won),
		dungeon = staffPatch(result.after),
	}, result
end

return {
	play = play,
}
