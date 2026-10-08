--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Rules = require(Shared.Rules)
local Logic = script.Parent.Parent.logic
local StartingState = require(Logic.StartingState)
local PlayRaid = require(Logic.PlayRaid)
local Repair = require(Logic.Repair)
local Hire = require(Logic.Hire)
local Restock = require(Logic.Restock)

local function repairFrontToBack(state: Types.PlayerState): Types.PlayerState
	for slot in state.dungeon.segments do
		local points = Rules.affordableRepair(state, slot)
		if points > 0 and Rules.canRepair(state, slot, points) then
			state = Repair.apply(state, slot, points)
		end
	end
	return state
end

local function hireSlimeIfAffordable(state: Types.PlayerState): Types.PlayerState
	for slot in state.dungeon.segments do
		if Rules.canBuyMob(state, slot, "Slime") then
			return Hire.apply(state, slot, "Slime")
		end
	end
	return state
end

local function restockIfAffordable(state: Types.PlayerState): Types.PlayerState
	local amount = Rules.affordableRestock(state)
	if amount > 0 then
		return Restock.apply(state, amount)
	end
	return state
end

local function playRaid(state: Types.PlayerState, rng: Random): (Types.PlayerState, boolean)
	local afterRaid, result = PlayRaid.play(state, rng)
	return restockIfAffordable(hireSlimeIfAffordable(repairFrontToBack(afterRaid))), result.won
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
	local wins, lowest, emptyStretches = 0, state.bronze, 0
	for raid = 1, raids or 1000 do
		if not Rules.attractsParties(state) then
			emptyStretches += 1 -- no treasure: in the game, nobody would come
			state = restockIfAffordable(state)
			continue
		end
		local won
		state, won = playRaid(state, rng)
		wins += if won then 1 else 0
		lowest = math.min(lowest, state.bronze)
		if raid % 50 == 0 then
			print(`raid {raid}: bronze {state.bronze}, treasure {state.treasure}, wins {wins}, condition {averageCondition(state.dungeon)}, mobs {countMobs(state.dungeon)}`)
		end
	end
	print(`done: win rate {math.round(wins / (raids or 1000) * 100)}%, final bronze {state.bronze}, lowest {lowest}, empty stretches {emptyStretches}`)
end

return {
	run = run,
}