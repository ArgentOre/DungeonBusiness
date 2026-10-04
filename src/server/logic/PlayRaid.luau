--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local PartyGen = require(script.Parent.PartyGen)
local RaidSim = require(script.Parent.RaidSim)
local Payout = require(script.Parent.Payout)
local Wages = require(script.Parent.Wages)

local function play(state: Types.PlayerState, rng: Random): (Types.PlayerState, Types.RaidResult)
	local party = PartyGen.make(state.dungeon, rng)
	local result = RaidSim.simulate(state.dungeon, party)
	local bronze = Wages.pay(state.bronze + Payout.amount(result), result.after)
	return { bronze = bronze, dungeon = result.after }, result
end

return {
	play = play,
}
