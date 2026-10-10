--!strict
-- Headless economy test. Runs the real raid logic with simple player policies,
-- because the economy has to hold up for players who fall behind, not just perfect ones.
-- From the Studio command bar (Run mode, F8):
--   require(game.ServerScriptService.Server.tests.EconomySim).runAll()
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Rules = require(Shared.Rules)
local Catalog = require(Shared.Catalog)
local Logic = script.Parent.Parent.logic
local StartingState = require(Logic.StartingState)
local PlayRaid = require(Logic.PlayRaid)
local Repair = require(Logic.Repair)
local Hire = require(Logic.Hire)
local Spoils = require(Logic.Spoils)

export type Policy = "steady" | "busy" | "neglect" | "recover"

type Stats = {
	wins: number,
	rookieRaids: number,
	lowestBronze: number,
}

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

local BRONZE_RESERVE = 60 -- a sensible player keeps enough bronze for repairs and wages

-- Sell until there's a bronze reserve, stock the rest as treasure, sell anything left over
local function sellStockSell(state: Types.PlayerState): Types.PlayerState
	local shortfall = math.max(0, BRONZE_RESERVE - state.bronze)
	local toSell = math.min(state.spoils, math.ceil(shortfall / Catalog.economy.bronzePerSpoil))
	if toSell > 0 then
		state = Spoils.sell(state, toSell)
	end
	local toStock = Rules.stockable(state)
	if toStock > 0 then
		state = Spoils.stock(state, toStock)
	end
	if state.spoils > 0 then
		state = Spoils.sell(state, state.spoils)
	end
	return state
end

local function sellAll(state: Types.PlayerState): Types.PlayerState
	return if state.spoils > 0 then Spoils.sell(state, state.spoils) else state
end

-- Sell and stock first, so repairs can be paid for
local function tendDungeon(state: Types.PlayerState): Types.PlayerState
	return hireSlimeIfAffordable(repairFrontToBack(sellStockSell(state)))
end

local function averageCondition(dungeon: Types.Dungeon): number
	local total = 0
	for _, segment in dungeon.segments do
		total += segment.condition
	end
	return math.round(total / #dungeon.segments)
end

-- Climbing out of a hole: fix the rooms with everything you have, then stock spoils
-- before selling. On rookie income, saving up a bronze reserve first never gets there.
local function recoverStep(state: Types.PlayerState): Types.PlayerState
	if averageCondition(state.dungeon) < 90 then
		return repairFrontToBack(sellAll(state))
	end
	local toStock = Rules.stockable(state)
	if toStock > 0 then
		state = Spoils.stock(state, toStock)
	end
	return repairFrontToBack(sellAll(state))
end

local function afterRaid(policy: Policy, state: Types.PlayerState, raid: number): Types.PlayerState
	if policy == "steady" then
		return tendDungeon(state)
	elseif policy == "recover" then
		return recoverStep(state)
	elseif policy == "busy" then
		return if raid % 3 == 0 then tendDungeon(state) else state
	end
	return sellAll(state)
end

local function simulate(policy: Policy, start: Types.PlayerState, raids: number, rng: Random): (Types.PlayerState, Stats)
	local state = start
	local stats: Stats = { wins = 0, rookieRaids = 0, lowestBronze = state.bronze }
	for raid = 1, raids do
		stats.rookieRaids += if Rules.chestEmpty(state) then 1 else 0
		local result
		state, result = PlayRaid.play(state, rng)
		stats.wins += if result.won then 1 else 0
		state = afterRaid(policy, state, raid)
		stats.lowestBronze = math.min(stats.lowestBronze, state.bronze)
	end
	return state, stats
end

local function report(label: string, start: Types.PlayerState, final: Types.PlayerState, stats: Stats, raids: number)
	local perRaid = (final.bronze - start.bronze) / raids
	print(
		`{label}: win {math.round(stats.wins / raids * 100)}%, bronze/raid {string.format("%.1f", perRaid)}, `
			.. `lowest {stats.lowestBronze}, final {final.bronze}, treasure {final.treasure}, `
			.. `rookie raids {math.round(stats.rookieRaids / raids * 100)}%, condition {averageCondition(final.dungeon)}`
	)
end

local function run(policy: Policy, raids: number?, seed: number?)
	local count = raids or 1000
	local start = StartingState.create()
	local final, stats = simulate(policy, start, count, Random.new(seed or 1))
	report(policy, start, final, stats, count)
end

-- Broke, no treasure, run-down rooms: can a sensible player climb out?
local function brokeStart(): Types.PlayerState
	local fresh = StartingState.create()
	local segments: { Types.Segment } = {}
	for _, segment in fresh.dungeon.segments do
		table.insert(segments, { kind = segment.kind, condition = 30, mobs = segment.mobs })
	end
	return { bronze = 0, treasure = 0, spoils = 0, reputation = 0, dungeon = { segments = segments } }
end

local function runRecovery(raids: number?, seed: number?)
	local count = raids or 100
	local start = brokeStart()
	local final, stats = simulate("recover", start, count, Random.new(seed or 1))
	report(`recovery ({count} raids)`, start, final, stats, count)
end

local LONG_RUN_POLICIES: { Policy } = { "steady", "busy", "neglect" }

local function runAll(seed: number?)
	for _, policy: Policy in LONG_RUN_POLICIES do
		run(policy, 1000, seed)
	end
	runRecovery(100, seed)
	print(
		`(loot per power {Catalog.party.lootPerPower}, rookie strength {Catalog.party.rookieStrength}, `
			.. `rookie gear {Catalog.party.rookieGearValue}, staff patch floor {Catalog.economy.staffPatchFloor})`
	)
end

return {
	run = run,
	runRecovery = runRecovery,
	runAll = runAll,
}
