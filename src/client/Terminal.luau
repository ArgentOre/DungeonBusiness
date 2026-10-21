--!strict
-- The administrator's terminal, opened at the hub's front desk. It fills the screen while
-- the dungeon keeps running behind it. Two tabs: the Ledger (the raid being told, every raid
-- this session, how the dungeon stands) and Sell. Numbers live here, not on the HUD.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Rules = require(Shared:WaitForChild("Rules"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local RaidReportView = require(script.Parent:WaitForChild("RaidReportView"))
local RaidLog = require(script.Parent:WaitForChild("RaidLog"))

local MAX_VISITORS = 30 -- about ten minutes of raids; older ones drop off the page
local MAX_SIZE = Vector2.new(680, 600) -- fills a phone, but not a monitor
local HEADER_HEIGHT = 44
local GAP = 10

export type Tab = "Ledger" | "Sell"
local TABS: { Tab } = { "Ledger", "Sell" }

export type Parts = {
	screen: ScreenGui,
	body: ScrollingFrame,
	tabs: { [Tab]: TextButton },
	pages: { [Tab]: Frame },
	standing: TextLabel,
	coming: TextLabel,
	latest: Frame, -- the raid being told, line by line
	overview: Frame,
	visitors: Frame,
	detail: Frame, -- one raid, opened from its row
	spoils: TextLabel,
	sell: TextButton,
}

local parts: Parts? = nil
local latestState: Types.PlayerState? = nil -- what Sell acts on, and the rooms a raid's detail names
local visitorRows: { TextButton } = {} -- newest first
local visitorCount = 0

local function standingText(outlook: Types.Outlook): string
	local holds = Rules.rankOf(outlook.holds).letter
	local fixed = Rules.rankOf(outlook.holdsFixed).letter
	if fixed == holds then
		return `Holds Rank {holds}`
	end
	return `Holds Rank {holds} as it stands · fixed up: Rank {fixed}`
end

local function visitorText(report: Types.RaidReport): string
	local rank = `{Rules.partyName(report.partyPower)} · Rank {Rules.rankOf(report.partyPower).letter}`
	if report.won then
		return `{rank} · held · +{report.spoilsDropped} spoils`
	end
	return if report.treasureTaken > 0 then `{rank} · got away · took {report.treasureTaken} treasure` else `{rank} · got away`
end

local function selectTab(tab: Tab)
	local shown = parts
	if not shown then
		return
	end
	for _, each: Tab in TABS do
		shown.pages[each].Visible = each == tab
		Ui.setSelected(shown.tabs[each], each == tab)
	end
end

local function showOverview()
	local shown = parts
	if shown then
		shown.detail.Visible = false
		shown.overview.Visible = true
	end
end

local function showDetail(report: Types.RaidReport, events: { Types.RaidEvent })
	local shown, state = parts, latestState
	if not (shown and state) then
		return
	end
	Ui.clear(shown.detail)
	RaidReportView.fill(shown.detail, report, state)
	Ui.text(shown.detail, "Blow by blow", Ui.STYLES.label)
	RaidLog.show(Ui.group(shown.detail, 2), events)
	Ui.secondaryButton(shown.detail, "Back to the ledger", showOverview)
	shown.overview.Visible = false
	shown.detail.Visible = true
	shown.body.CanvasPosition = Vector2.new(0, 0)
end

local function makeFrame(screen: ScreenGui): Frame
	local frame = Ui.panel(screen, 0, GAP)
	frame.AutomaticSize = Enum.AutomaticSize.None
	frame.Size = UDim2.fromScale(0.9, 0.85)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = MAX_SIZE
	limit.Parent = frame
	return frame
end

local function makeHeader(frame: Frame, close: () -> ()): { [Tab]: TextButton }
	local header = Ui.group(frame, 8)
	local layout = header:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.FillDirection = Enum.FillDirection.Horizontal
	end
	local tabs: { [Tab]: TextButton } = {}
	for _, tab: Tab in TABS do
		tabs[tab] = Ui.secondaryButton(header, tab, function()
			selectTab(tab)
		end)
	end
	Ui.secondaryButton(header, "Back to work", close)
	for _, button in header:GetChildren() do
		if button:IsA("TextButton") then
			button.Size = UDim2.new(1 / 3, -6, 0, HEADER_HEIGHT)
		end
	end
	return tabs
end

local function makeBody(frame: Frame): ScrollingFrame
	local body = Instance.new("ScrollingFrame")
	body.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + GAP))
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.CanvasSize = UDim2.fromOffset(0, 0)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 6
	body.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar -- rows stop at the bar, not under it
	body.LayoutOrder = #frame:GetChildren()
	body.Parent = frame
	return body
end

local function onSellClicked(onSell: (amount: number) -> ())
	local state = latestState
	if state and state.spoils > 0 then
		onSell(state.spoils)
	end
end

-- Builds the terminal once, closed. `onSell` asks the server to sell that many spoils
local function create(parent: Instance, onSell: (amount: number) -> ()): Parts
	local screen = Instance.new("ScreenGui")
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 1 -- above the HUD
	screen.Enabled = false
	screen.Parent = parent
	local frame = makeFrame(screen)
	local tabs = makeHeader(frame, function()
		screen.Enabled = false
	end)
	local body = makeBody(frame)

	local ledger = Ui.group(body, 12)
	local overview = Ui.group(ledger, 12)
	Ui.text(overview, "Your dungeon", Ui.STYLES.label)
	local standing = Ui.text(overview, "", Ui.STYLES.body)
	local coming = Ui.text(overview, "", Ui.STYLES.body)
	Ui.text(overview, "Latest raid", Ui.STYLES.label)
	local latest = Ui.group(overview, 2)
	Ui.text(overview, "Visitors", Ui.STYLES.label)
	local visitors = Ui.group(overview, 0)
	local detail = Ui.group(ledger, 12)
	detail.Visible = false

	local sellPage = Ui.group(body, 12)
	Ui.text(sellPage, "What they left behind", Ui.STYLES.label)
	local spoils = Ui.text(sellPage, "", Ui.STYLES.money)
	local sell = Ui.primaryButton(sellPage, "", function()
		onSellClicked(onSell)
	end)
	Ui.text(sellPage, "Rather keep them as treasure? Stock them in the Treasure Room.", Ui.STYLES.muted)

	local made: Parts = {
		screen = screen,
		body = body,
		tabs = tabs,
		pages = { Ledger = ledger, Sell = sellPage },
		standing = standing,
		coming = coming,
		latest = latest,
		overview = overview,
		visitors = visitors,
		detail = detail,
		spoils = spoils,
		sell = sell,
	}
	parts = made
	selectTab("Ledger")
	return made
end

local function open()
	local shown = parts
	if shown then
		shown.screen.Enabled = true
	end
end

local function render(state: Types.PlayerState, outlook: Types.Outlook)
	latestState = state
	local shown = parts
	if not shown then
		return
	end
	shown.standing.Text = standingText(outlook)
	shown.coming.Text = `Coming: Rank {Rules.rankOf(outlook.coming).letter}`
	local hasSpoils = state.spoils > 0
	shown.spoils.Text = if hasSpoils then `{state.spoils} spoils` else "Nothing yet. Held raids leave spoils behind."
	shown.sell.Text = `Sell it all · +{state.spoils * Catalog.economy.bronzePerSpoil} bronze`
	shown.sell.Visible = hasSpoils
end

-- A raid that has been told goes on the ledger, newest on top
local function addRaid(report: Types.RaidReport, events: { Types.RaidEvent })
	local shown = parts
	if not shown then
		return
	end
	visitorCount += 1
	local row = Ui.listRow(shown.visitors, visitorText(report), function()
		showDetail(report, events)
	end)
	row.LayoutOrder = -visitorCount
	table.insert(visitorRows, 1, row)
	if #visitorRows > MAX_VISITORS then
		local oldest = table.remove(visitorRows)
		if oldest then
			oldest:Destroy()
		end
	end
end

return {
	create = create,
	open = open,
	render = render,
	addRaid = addRaid,
}
