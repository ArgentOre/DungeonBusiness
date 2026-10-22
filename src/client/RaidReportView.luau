--!strict
-- One raid on the ledger: how it went, why, where it ended, and the payday.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Rules = require(Shared:WaitForChild("Rules"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local function roomName(state: Types.PlayerState, slot: number): string
	local segment = state.dungeon.segments[slot]
	return if segment then Catalog.rooms[segment.kind].displayName else "the dungeon"
end

local function rankLetter(report: Types.RaidReport): string
	return Rules.rankOf(report.partyPower).letter
end

local function headline(report: Types.RaidReport): string
	local who = `{Rules.partyName(report.partyPower)}, Rank {rankLetter(report)}`
	if report.won then
		return `{who}: sent home!`
	end
	return if report.treasureTaken > 0 then `{who}: stole {report.treasureTaken} treasure!` else `{who}: got away!`
end

local function whereItEnded(report: Types.RaidReport, state: Types.PlayerState): string
	if report.won then
		return `They gave up in the {roomName(state, report.endSlot)}.`
	end
	if report.reputation > 0 then
		return "They kept their gear, so nothing dropped. Word spreads that your dungeon can be beaten, so weaker parties come for a while."
	end
	return "They kept their gear, so nothing dropped."
end

-- Why the raid went the way it did, in plain words, or nil when nothing stood out
local function reason(report: Types.RaidReport): string?
	local cause = Rules.raidCause(report)
	local rank = `Rank {rankLetter(report)} party`
	if cause == "WornRooms" then
		return "worn rooms let them through"
	elseif cause == "Rookies" then
		return "an empty chest only draws rookies"
	elseif cause == "Fame" then
		return `your fame drew a {rank}`
	elseif cause == "TooTough" then
		return `a {rank}, too tough to stop`
	end
	return nil
end

local function signed(amount: number): string
	return if amount >= 0 then `+{amount}` else `−{-amount}`
end

local function addPayday(parent: Instance, report: Types.RaidReport)
	local box = Ui.group(parent, 4)
	Ui.text(box, `Spoils  {signed(report.spoilsDropped)}`, Ui.STYLES.money)
	Ui.text(box, "Sell them here, or stock them in the vault in the Treasure Room.", Ui.STYLES.muted)
	Ui.text(box, `Wages  −{report.wagesPaid} bronze`, Ui.STYLES.muted)
end

local function fill(container: Instance, report: Types.RaidReport, state: Types.PlayerState)
	Ui.text(container, headline(report), Ui.STYLES.heading)
	local why = reason(report)
	if why then
		Ui.text(container, `Why: {why}`, Ui.STYLES.label)
	end
	Ui.text(container, whereItEnded(report, state), Ui.STYLES.muted)
	addPayday(container, report)
end

return {
	fill = fill,
}
