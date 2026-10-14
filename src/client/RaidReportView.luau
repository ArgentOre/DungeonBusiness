--!strict
-- The card shown after every raid: how it went, the payday, and what needs fixing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Rules = require(Shared:WaitForChild("Rules"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local CARD_WIDTH = 420

local card: Frame? = nil

local function hide()
	if card then
		card:Destroy()
		card = nil
	end
end

local function roomName(state: Types.PlayerState, slot: number): string
	local segment = state.dungeon.segments[slot]
	return if segment then Catalog.rooms[segment.kind].displayName else "the dungeon"
end

local function rankLetter(report: Types.RaidReport): string
	return Rules.rankOf(report.partyPower).letter
end

local function headline(report: Types.RaidReport): string
	if report.won then
		return `Rank {rankLetter(report)} party defeated!`
	end
	return if report.treasureTaken > 0 then `They stole {report.treasureTaken} treasure!` else "They got away!"
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

-- Why the raid went the way it did, in plain words, or nil when nothing stood out.
-- A win against a famous party needs no reason: fame only explains why they got away
local function reason(report: Types.RaidReport): string?
	if report.fixingWouldHaveHeld then
		return "worn rooms let them through"
	end
	if report.rookies then
		return "an empty chest only draws rookies"
	end
	if report.won then
		return nil
	end
	local rank = `Rank {rankLetter(report)} party`
	return if report.reputation > 0 then `your fame drew a {rank}` else `a {rank}, too tough to stop`
end

local function signed(amount: number): string
	return if amount >= 0 then `+{amount}` else `−{-amount}`
end

local function addPayday(parent: Frame, report: Types.RaidReport)
	local box = Ui.group(parent, 4)
	Ui.text(box, `Spoils  {signed(report.spoilsDropped)}`, Ui.STYLES.money)
	Ui.text(box, "Sell them for bronze, or stock them as treasure, in the Treasure Room.", Ui.STYLES.muted)
	Ui.text(box, `Wages  −{report.wagesPaid} bronze`, Ui.STYLES.muted)
end

local function addNeedsFixing(parent: Frame, state: Types.PlayerState)
	local box = Ui.group(parent, 4)
	Ui.text(box, "Needs fixing", Ui.STYLES.label)
	local anything = false
	for _, segment in state.dungeon.segments do
		if segment.condition < 100 then
			anything = true
			local name = Catalog.rooms[segment.kind].displayName
			Ui.text(box, `{name} · {segment.condition}% · fix it in the room`, Ui.STYLES.warning)
		end
	end
	if not anything then
		Ui.text(box, "Nothing. Spotless!", Ui.STYLES.muted)
	end
end

-- One line for the notice after each raid; tapping the notice opens the full card
local function summary(report: Types.RaidReport): string
	local line = headline(report)
	local why = reason(report)
	if why then
		line ..= ` · {why}`
	end
	if report.spoilsDropped > 0 then
		line ..= `  +{report.spoilsDropped} spoils`
	end
	return line
end

local function show(screen: ScreenGui, report: Types.RaidReport, state: Types.PlayerState, onShowLog: () -> ())
	hide()
	local frame = Ui.panel(screen, CARD_WIDTH, 16)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	Ui.text(frame, headline(report), Ui.STYLES.heading)
	local why = reason(report)
	if why then
		Ui.text(frame, `Why: {why}`, Ui.STYLES.label)
	end
	Ui.text(frame, whereItEnded(report, state), Ui.STYLES.muted)
	addPayday(frame, report)
	addNeedsFixing(frame, state)
	Ui.primaryButton(frame, "Back to work", hide)
	Ui.secondaryButton(frame, "Raid log", function()
		hide()
		onShowLog()
	end)
	card = frame
end

return {
	summary = summary,
	show = show,
}
