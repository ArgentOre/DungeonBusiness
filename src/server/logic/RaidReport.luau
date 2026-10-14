--!strict
-- What the player needs to know after a raid. The client works out what needs
-- fixing from the new state, so it isn't repeated here.
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Rules = require(Shared.Rules)
local RaidSim = require(script.Parent.RaidSim)
local Condition = require(script.Parent.Condition)

-- A raid's last event is always PartyDefeated or PartyEscaped, and both carry the room
local function endSlot(events: { Types.RaidEvent }): number
	local last = events[#events]
	return if last then last.slot else 0
end

-- Replays the same party against the same rooms, fully fixed. Raids are deterministic,
-- so this is the exact answer to "was it the wear?", not a guess
local function fixingWouldHaveHeld(dungeon: Types.Dungeon, result: Types.RaidResult): boolean
	return not result.won and RaidSim.simulate(Condition.atLeast(dungeon, 100), result.party).won
end

local function make(before: Types.PlayerState, after: Types.PlayerState, result: Types.RaidResult): Types.RaidReport
	return {
		won = result.won,
		rookies = Rules.chestEmpty(before),
		spoilsDropped = after.spoils - before.spoils,
		wagesPaid = before.bronze - after.bronze,
		endSlot = endSlot(result.events),
		treasureTaken = before.treasure - after.treasure,
		reputation = before.reputation,
		fixingWouldHaveHeld = fixingWouldHaveHeld(before.dungeon, result),
		partyPower = result.party.power,
	}
end

return {
	make = make,
}
