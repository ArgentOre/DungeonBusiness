--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)
local PartyGen = require(script.Parent.PartyGen)
local RaidSim = require(script.Parent.RaidSim)
local Payout = require(script.Parent.Payout)
local Wages = require(script.Parent.Wages)

-- A party that escapes carries some of the stocked treasure away with it
local function treasureAfter(treasure: number, won: boolean): number
	if won then
		return treasure
	end
	return math.max(0, treasure - Catalog.economy.treasureTakenPerEscape)
end

local function play(state: Types.PlayerState, rng: Random): (Types.PlayerState, Types.RaidResult)
	local party = PartyGen.make(state.dungeon, rng)
	local result = RaidSim.simulate(state.dungeon, party)
	local bronze = Wages.pay(state.bronze + Payout.amount(result), result.after)
	return { bronze = bronze, treasure = treasureAfter(state.treasure, result.won), dungeon = result.after }, result
end

return {
	play = play,
}
