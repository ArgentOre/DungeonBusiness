--!strict
-- The HUD: bronze, the doors, the raid feed, the dungeon's rooms, and the raid log.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Types = require(Shared:WaitForChild("Types"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Rules = require(Shared:WaitForChild("Rules"))
local EventText = require(Shared:WaitForChild("EventText"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local RaidReportView = require(script.Parent:WaitForChild("RaidReportView"))
local RoomPanel = require(script.Parent:WaitForChild("RoomPanel"))
local RaidFeed = require(script.Parent:WaitForChild("RaidFeed"))

local GetState = Remotes:WaitForChild("GetState") :: RemoteFunction
local SetDoorsOpen = Remotes:WaitForChild("SetDoorsOpen") :: RemoteEvent
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent
local RaidFinished = Remotes:WaitForChild("RaidFinished") :: RemoteEvent

local EDGE = 16 -- gap between the HUD and the screen edge

local screen = Instance.new("ScreenGui")
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local currentState: Types.PlayerState? = nil
local doorsAreOpen = false
local nextPartyAt: number? = nil -- os.clock() time; an estimate, the server decides

-- Top left: bronze, and the toggle that hides the big panels
local bronzePanel = Ui.panel(screen, 200, 8)
bronzePanel.Position = UDim2.fromOffset(EDGE, EDGE)
local bronzeLabel = Ui.text(bronzePanel, "… bronze", Ui.STYLES.money)

-- Top right: the one main action, and when the next party is due
local raidColumn = Ui.group(screen, 6)
raidColumn.AnchorPoint = Vector2.new(1, 0)
raidColumn.Position = UDim2.new(1, -EDGE, 0, EDGE)
raidColumn.Size = UDim2.fromOffset(240, 0)
local doorsButton: TextButton
doorsButton = Ui.primaryButton(raidColumn, "Open the doors", function()
	doorsAreOpen = not doorsAreOpen
	doorsButton.Text = if doorsAreOpen then "Close the doors" else "Open the doors"
	nextPartyAt = if doorsAreOpen then os.clock() else nil
	SetDoorsOpen:FireServer(doorsAreOpen)
end)
local doorsStatus = Ui.text(raidColumn, "Doors closed", Ui.STYLES.muted)

-- Bottom left: the rooms
local dungeonPanel = Ui.panel(screen, 340, 12)
dungeonPanel.AnchorPoint = Vector2.new(0, 1)
dungeonPanel.Position = UDim2.new(0, EDGE, 1, -EDGE)
Ui.text(dungeonPanel, "Your dungeon", Ui.STYLES.label)
local roomRows = Ui.group(dungeonPanel, 14)

-- Bottom right: the raid log, opened from a raid report
local logPanel = Ui.panel(screen, 360, 6)
logPanel.AnchorPoint = Vector2.new(1, 1)
logPanel.Position = UDim2.new(1, -EDGE, 1, -EDGE)
logPanel.Visible = false
Ui.text(logPanel, "Raid log", Ui.STYLES.label)
local logLines = Ui.group(logPanel, 2)
Ui.secondaryButton(logPanel, "Close", function()
	logPanel.Visible = false
end)

local panelToggle: TextButton
panelToggle = Ui.secondaryButton(bronzePanel, "Hide panels", function()
	local visible = not dungeonPanel.Visible
	dungeonPanel.Visible = visible
	logPanel.Visible = visible and logPanel.Visible
	panelToggle.Text = if visible then "Hide panels" else "Show panels"
end)

local function fillLog(events: { Types.RaidEvent })
	Ui.clear(logLines)
	for _, event in events do
		Ui.text(logLines, EventText.format(event), Ui.STYLES.muted)
	end
end

local function openRaid(entry: RaidFeed.Entry)
	if not currentState then
		return
	end
	RaidReportView.show(screen, entry.report, currentState, function()
		fillLog(entry.events)
		logPanel.Visible = true
	end)
end

-- Top centre: the last few raids; tap one for its full report
local feed = RaidFeed.create(screen, openRaid)
feed.AnchorPoint = Vector2.new(0.5, 0)
feed.Position = UDim2.new(0.5, 0, 0, EDGE)
feed.Size = UDim2.fromOffset(380, 0)

local function render(state: Types.PlayerState)
	currentState = state
	bronzeLabel.Text = `{state.bronze} bronze`
	RoomPanel.render(roomRows, state)
end

local function doorsStatusText(): string
	if not doorsAreOpen then
		return "Doors closed"
	end
	if currentState and Rules.chestEmpty(currentState) then
		return "Only junk to steal: rookies only"
	end
	local secondsLeft = if nextPartyAt then math.ceil(nextPartyAt - os.clock()) else 0
	return if secondsLeft > 0 then `Next party in {secondsLeft}s` else "A party is on the way…"
end

local function onRaidFinished(events: { Types.RaidEvent }, report: Types.RaidReport)
	nextPartyAt = os.clock() + Catalog.economy.raidIntervalSeconds
	RaidFeed.add(report, events)
end

StateChanged.OnClientEvent:Connect(render)
RaidFinished.OnClientEvent:Connect(onRaidFinished)

local initialState = GetState:InvokeServer() :: Types.PlayerState?
if initialState then
	render(initialState)
end

task.spawn(function()
	while true do
		doorsStatus.Text = doorsStatusText()
		task.wait(0.25)
	end
end)
