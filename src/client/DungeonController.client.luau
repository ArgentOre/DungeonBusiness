--!strict
-- The HUD: bronze, the doors, the raid feed, the dungeon's rooms, and the raid log.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Types = require(Shared:WaitForChild("Types"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Rules = require(Shared:WaitForChild("Rules"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local RaidReportView = require(script.Parent:WaitForChild("RaidReportView"))
local RoomPanel = require(script.Parent:WaitForChild("RoomPanel"))
local RaidFeed = require(script.Parent:WaitForChild("RaidFeed"))
local RaidLog = require(script.Parent:WaitForChild("RaidLog"))

local GetState = Remotes:WaitForChild("GetState") :: RemoteFunction
local SetDoorsOpen = Remotes:WaitForChild("SetDoorsOpen") :: RemoteEvent
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent
local RaidFinished = Remotes:WaitForChild("RaidFinished") :: RemoteEvent

local EDGE = 16 -- gap between the HUD and the screen edge
local TELLING_SHARE = 0.75 -- a raid is told over most of the gap before the next party, leaving a breath

local screen = Instance.new("ScreenGui")
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local currentState: Types.PlayerState? = nil
local doorsAreOpen = false
local lastPartyAt: number? = nil -- os.clock() time the last party came; the countdown is an estimate, the server decides

-- Top left: bronze, and the toggle that hides the big panels
local bronzePanel = Ui.panel(screen, 200, 8)
bronzePanel.Position = UDim2.fromOffset(EDGE, EDGE)
local bronzeLabel = Ui.text(bronzePanel, "… bronze", Ui.STYLES.money)
local outlookLabel = Ui.text(bronzePanel, "", Ui.STYLES.muted)

-- Top right: the one main action, and when the next party is due
local raidColumn = Ui.group(screen, 6)
raidColumn.AnchorPoint = Vector2.new(1, 0)
raidColumn.Position = UDim2.new(1, -EDGE, 0, EDGE)
raidColumn.Size = UDim2.fromOffset(240, 0)
local doorsButton: TextButton
doorsButton = Ui.primaryButton(raidColumn, "Open the doors", function()
	doorsAreOpen = not doorsAreOpen
	doorsButton.Text = if doorsAreOpen then "Close the doors" else "Open the doors"
	SetDoorsOpen:FireServer(doorsAreOpen)
end)
local doorsStatus = Ui.text(raidColumn, "Doors closed", Ui.STYLES.muted)

-- Bottom left: the rooms
local dungeonPanel = Ui.panel(screen, 340, 12)
dungeonPanel.AnchorPoint = Vector2.new(0, 1)
dungeonPanel.Position = UDim2.new(0, EDGE, 1, -EDGE)
Ui.text(dungeonPanel, "Your dungeon", Ui.STYLES.label)
local roomRows = Ui.group(dungeonPanel, 14)

-- Bottom right: the raid log, open from the start so there's always something happening
local logPanel = Ui.panel(screen, 360, 6)
logPanel.AnchorPoint = Vector2.new(1, 1)
logPanel.Position = UDim2.new(1, -EDGE, 1, -EDGE)
Ui.text(logPanel, "Raid log", Ui.STYLES.label)
local logLines = Ui.group(logPanel, 2)
Ui.secondaryButton(logPanel, "Close", function()
	logPanel.Visible = false
end)

local panelToggle: TextButton
panelToggle = Ui.secondaryButton(bronzePanel, "Hide panels", function()
	local visible = not dungeonPanel.Visible
	dungeonPanel.Visible = visible
	logPanel.Visible = visible
	panelToggle.Text = if visible then "Hide panels" else "Show panels"
end)

local function openRaid(entry: RaidFeed.Entry)
	if not currentState then
		return
	end
	RaidReportView.show(screen, entry.report, currentState, function()
		RaidLog.show(logLines, entry.events)
		logPanel.Visible = true
	end)
end

-- Top centre: the last few raids; tap one for its full report
local feed = RaidFeed.create(screen, openRaid)
feed.AnchorPoint = Vector2.new(0.5, 0)
feed.Position = UDim2.new(0.5, 0, 0, EDGE)
feed.Size = UDim2.fromOffset(380, 0)

-- Ranks, not powers: an exact comparison would tell who wins before the raid is told
local function renderOutlook(outlook: Types.Outlook)
	local holds, coming = Rules.rankOf(outlook.holds), Rules.rankOf(outlook.coming)
	outlookLabel.Text = `Holds Rank {holds.letter} · Rank {coming.letter} parties coming`
	outlookLabel.TextColor3 = if coming.minPower > holds.minPower then Ui.THEME.needsFix else Ui.THEME.mutedText
end

local function render(state: Types.PlayerState, outlook: Types.Outlook)
	currentState = state
	bronzeLabel.Text = `{state.bronze} bronze`
	renderOutlook(outlook)
	RoomPanel.render(roomRows, state)
end

local function doorsStatusText(): string
	if not doorsAreOpen then
		return "Doors closed"
	end
	local now = os.clock()
	local secondsLeft = math.ceil(Rules.nextPartyAt(lastPartyAt, now) - now)
	return if secondsLeft > 0 then `Next party in {secondsLeft}s` else "A party is on the way…"
end

-- The feed shows how the raid ended only once the log has told it, so the result isn't spoiled
local function onRaidFinished(events: { Types.RaidEvent }, report: Types.RaidReport)
	lastPartyAt = os.clock()
	RaidLog.narrate(logLines, events, Catalog.economy.raidIntervalSeconds * TELLING_SHARE, function()
		RaidFeed.add(report, events)
	end)
end

StateChanged.OnClientEvent:Connect(render)
RaidFinished.OnClientEvent:Connect(onRaidFinished)

local initialState, initialOutlook = GetState:InvokeServer()
if initialState and initialOutlook then
	render(initialState :: Types.PlayerState, initialOutlook :: Types.Outlook)
end

task.spawn(function()
	while true do
		doorsStatus.Text = doorsStatusText()
		task.wait(0.25)
	end
end)
