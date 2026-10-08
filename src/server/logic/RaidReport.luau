--!strict
-- What the player needs to know after a raid. The client works out what needs
-- fixing from the new state, so it isn't repeated here.
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Payout = require(script.Parent.Payout)

-- A raid's last event is always PartyDefeated or PartyEscaped, and both carry the room
local function endSlot(events: { Types.RaidEvent }): number
	local last = events[#events]
	return if last then last.slot else 0
end

local function make(before: Types.PlayerState, after: Types.PlayerState, result: Types.RaidResult): Types.RaidReport
	local earned = Payout.amount(result)
	return {
		won = result.won,
		earned = earned,
		wagesPaid = before.bronze + earned - after.bronze,
		endSlot = endSlot(result.events),
		treasureTaken = before.treasure - after.treasure,
	}
end

return {
	make = make,
}
