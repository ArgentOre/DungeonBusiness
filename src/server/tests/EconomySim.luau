--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Rules = require(Shared.Rules)
local Logic = script.Parent.Parent.logic
local StartingState = require(Logic.StartingState)
local PartyGen = require(Logic.PartyGen)
local RaidSim = require(Logic.RaidSim)
local Payout = require(Logic.Payout)
local Wages = require(Logic.Wages)
local Repair = require(Logic.Repair)

local function repairFrontToBack(state: Types.PlayerState): Types.PlayerState
	for slot, segment in state.dungeon.segments do
		local points = math.min(100 - segment.condition, state.bronze // Rules.repairCost(segment, 1))
		if points > 0 and Rules.canRepair(state, slot, points) then
			state = Repair.apply(state, slot, points)
		end
	end
	return state
end

local function playRaid(state: Types.PlayerState, rng: Random): (Types.PlayerState, boolean)
	local party = PartyGen.make(state.dungeon, rng)
	local result = RaidSim.simulate(state.dungeon, party)
	local bronze = Wages.pay(state.bronze + Payout.amount(result), result.after)
	return repairFrontToBack({ bronze = bronze, dungeon = result.after }), result.won
end

local function countMobs(dungeon: Types.Dungeon): number
	local total = 0
	for _, segment in dungeon.segments do
		total += #segment.mobs
	end
	return total
end

local function averageCondition(dungeon: Types.Dungeon): number
	local total = 0
	for _, segment in dungeon.segments do
		total += segment.condition
	end
	return math.round(total / #dungeon.segments)
end

local function run(raids: number?, seed: number?)
	local rng = Random.new(seed or 1)
	local state = StartingState.create()
	local wins, lowest = 0, state.bronze
	for raid = 1, raids or 1000 do
		local won
		state, won = playRaid(state, rng)
		wins += if won then 1 else 0
		lowest = math.min(lowest, state.bronze)
		if raid % 50 == 0 then
			print(`raid {raid}: bronze {state.bronze}, wins {wins}, condition {averageCondition(state.dungeon)}, mobs {countMobs(state.dungeon)}`)
		end
	end
	print(`done: win rate {math.round(wins / (raids or 1000) * 100)}%, final bronze {state.bronze}, lowest {lowest}`)
end

return {
	run = run,
}