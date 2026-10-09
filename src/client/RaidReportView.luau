--!strict
-- The card shown after every raid: how it went, the payday, and what needs fixing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Catalog = require(Shared:WaitForChild("Catalog"))
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

local function headline(report: Types.RaidReport): string
	if report.won then
		return if report.rookies then "Rookies defeated!" else "The dungeon held!"
	end
	return if report.treasureTaken > 0 then `They stole {report.treasureTaken} treasure!` else "They got away!"
end

local function whereItEnded(report: Types.RaidReport, state: Types.PlayerState): string
	if report.won then
		return `They gave up in the {roomName(state, report.endSlot)}.`
	end
	return "They kept their gear, so nothing dropped. Stock spoils to refill the treasure."
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

local function fixHint(segment: Types.Segment): string
	return if Catalog.rooms[segment.kind].repairInWorld then " · fix it in the room" else ""
end

local function addNeedsFixing(parent: Frame, state: Types.PlayerState)
	local box = Ui.group(parent, 4)
	Ui.text(box, "Needs fixing", Ui.STYLES.label)
	local anything = false
	for _, segment in state.dungeon.segments do
		if segment.condition < 100 then
			anything = true
			local name = Catalog.rooms[segment.kind].displayName
			Ui.text(box, `{name} · {segment.condition}%{fixHint(segment)}`, Ui.STYLES.warning)
		end
	end
	if not anything then
		Ui.text(box, "Nothing. Spotless!", Ui.STYLES.muted)
	end
end

-- One line for the notice after each raid; tapping the notice opens the full card
local function summary(report: Types.RaidReport): string
	if report.spoilsDropped > 0 then
		return `{headline(report)}  +{report.spoilsDropped} spoils`
	end
	return headline(report)
end

local function show(screen: ScreenGui, report: Types.RaidReport, state: Types.PlayerState, onShowLog: () -> ())
	hide()
	local frame = Ui.panel(screen, CARD_WIDTH, 16)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	Ui.text(frame, headline(report), Ui.STYLES.heading)
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
	hide = hide,
}
