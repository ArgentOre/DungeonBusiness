--!strict
-- The card shown after every raid: how it went, the payday, and what needs fixing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Ui = require(script.Parent.Ui)

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
	return if report.won then "The dungeon held!" else "The party got away!"
end

local function whereItEnded(report: Types.RaidReport, state: Types.PlayerState): string
	if report.won then
		return `They gave up in the {roomName(state, report.endSlot)}.`
	end
	return "They escaped with some treasure."
end

local function signed(amount: number): string
	return if amount >= 0 then `+{amount}` else `−{-amount}`
end

local function addPayday(parent: Frame, report: Types.RaidReport)
	local box = Ui.group(parent, 4)
	Ui.text(box, `Loot  {signed(report.earned)} bronze`, Ui.STYLES.money)
	Ui.text(box, `Wages  −{report.wagesPaid} bronze`, Ui.STYLES.muted)
	Ui.text(box, `Payday  {signed(report.earned - report.wagesPaid)} bronze`, Ui.STYLES.money)
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
	show = show,
	hide = hide,
}
