--!strict
-- The HUD (bronze, the doors, Mai at the front desk, the dungeon's rooms) and the terminal
-- at the hub desk, wired to the server.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Types = require(Shared:WaitForChild("Types"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Rules = require(Shared:WaitForChild("Rules"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local RoomPanel = require(script.Parent:WaitForChild("RoomPanel"))
local Lines = require(script.Parent:WaitForChild("Lines"))
local Mai = require(script.Parent:WaitForChild("Mai"))
local RaidLog = require(script.Parent:WaitForChild("RaidLog"))
local Terminal = require(script.Parent:WaitForChild("Terminal"))

local GetState = Remotes:WaitForChild("GetState") :: RemoteFunction
local SetDoorsOpen = Remotes:WaitForChild("SetDoorsOpen") :: RemoteEvent
local SellSpoils = Remotes:WaitForChild("SellSpoils") :: RemoteEvent
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent
local RaidFinished = Remotes:WaitForChild("RaidFinished") :: RemoteEvent
local DebugTravel = Remotes:WaitForChild("DebugTravel") :: RemoteEvent

local EDGE = 16 -- gap between the HUD and the screen edge
local TELLING_SHARE = 0.75 -- a raid is told over most of the gap before the next party, leaving a breath

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local screen = Instance.new("ScreenGui")
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.Parent = playerGui

local currentOutlook: Types.Outlook? = nil
local doorsAreOpen = false
local lineCount = 0 -- moves through each moment's lines, so the same line doesn't come twice in a row

local function nextVariant(): number
	lineCount += 1
	return lineCount
end
local lastPartyAt: number? = nil -- os.clock() time the last party came; the countdown is an estimate, the server decides

-- Top left: bronze, and the toggle that hides the big panels
local bronzePanel = Ui.panel(screen, 200, 8)
bronzePanel.Position = UDim2.fromOffset(EDGE, EDGE)
local bronzeLabel = Ui.text(bronzePanel, "… bronze", Ui.STYLES.money)
local holdsLabel = Ui.text(bronzePanel, "", Ui.STYLES.label)
local comingLabel = Ui.text(bronzePanel, "", Ui.STYLES.label)

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
	Mai.say(Lines.doors(doorsAreOpen, nextVariant()), not doorsAreOpen)
end)
local doorsStatus = Ui.text(raidColumn, "Doors closed", Ui.STYLES.muted)

-- Bottom left: the rooms
local dungeonPanel = Ui.panel(screen, 340, 12)
dungeonPanel.AnchorPoint = Vector2.new(0, 1)
dungeonPanel.Position = UDim2.new(0, EDGE, 1, -EDGE)
Ui.text(dungeonPanel, "Your dungeon", Ui.STYLES.label)
local roomRows = Ui.group(dungeonPanel, 14)

-- Admin debug tool, Studio only (the server checks too): travel until conveyors exist
if RunService:IsStudio() then
	local inDungeon = false
	local travelButton: TextButton
	travelButton = Ui.secondaryButton(bronzePanel, "[debug] Go to my dungeon", function()
		inDungeon = not inDungeon
		DebugTravel:FireServer(if inDungeon then "Dungeon" else "Hub")
		travelButton.Text = if inDungeon then "[debug] Go to the hub" else "[debug] Go to my dungeon"
	end)
end

local panelToggle: TextButton
panelToggle = Ui.secondaryButton(bronzePanel, "Hide panels", function()
	local visible = not dungeonPanel.Visible
	dungeonPanel.Visible = visible
	panelToggle.Text = if visible then "Hide panels" else "Show panels"
end)

-- The terminal, at the hub desk: the ledger and selling. The server checks every sale
local terminal = Terminal.create(playerGui, function(amount: number)
	SellSpoils:FireServer(amount)
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == Catalog.terminal.promptName then
		Terminal.open()
	end
end)

-- Bottom centre: Mai, who tells each raid in one line. Tapped, she points to the ledger
local frontDesk = Ui.group(screen, 0)
frontDesk.AnchorPoint = Vector2.new(0.5, 1)
frontDesk.Position = UDim2.new(0.5, 0, 1, -EDGE)
frontDesk.Size = UDim2.fromOffset(500, 0)
Mai.create(frontDesk, function()
	Mai.say(Lines.ledgerHint(nextVariant()))
end)

-- Ranks, not powers: an exact comparison would tell who wins before the raid is told
local function renderOutlook(outlook: Types.Outlook)
	holdsLabel.Text = `Your dungeon: Rank {Rules.rankOf(outlook.holds).letter}`
	comingLabel.Text = `Coming: Rank {Rules.rankOf(outlook.coming).letter}`
	local danger = Rules.verdict(outlook.coming, outlook.holds) == "Danger"
	comingLabel.TextColor3 = if danger then Ui.THEME.needsFix else Ui.THEME.text
end

local function render(state: Types.PlayerState, outlook: Types.Outlook)
	currentOutlook = outlook
	bronzeLabel.Text = `{state.bronze} bronze`
	renderOutlook(outlook)
	RoomPanel.render(roomRows, state)
	Terminal.render(state, outlook)
end

local function doorsStatusText(): string
	if not doorsAreOpen then
		return "Doors closed"
	end
	local now = os.clock()
	local secondsLeft = math.ceil(Rules.nextPartyAt(lastPartyAt, now) - now)
	return if secondsLeft > 0 then `Next party in {secondsLeft}s` else "A party is on the way…"
end

-- Mai announces the party as the telling starts. How it went (her line, the ledger row)
-- waits until it's told, so the result isn't spoiled
local function onRaidFinished(events: { Types.RaidEvent }, report: Types.RaidReport)
	lastPartyAt = os.clock()
	local outlook = currentOutlook
	if outlook then
		Mai.say(Lines.arrival(report, outlook.holds, nextVariant()))
	end
	RaidLog.narrate(terminal.latest, events, Catalog.economy.raidIntervalSeconds * TELLING_SHARE, function()
		Terminal.addRaid(report, events)
		Mai.say(Lines.result(report, nextVariant()))
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
