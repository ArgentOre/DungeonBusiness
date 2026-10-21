--!strict
-- The HUD (bronze, the door sign, Mai at the front desk, the room you're in, worn rooms,
-- the room panel) and the terminal at the hub desk, wired to the server.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Types = require(Shared:WaitForChild("Types"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local RoomPanel = require(script.Parent:WaitForChild("RoomPanel"))
local Lines = require(script.Parent:WaitForChild("Lines"))
local Mai = require(script.Parent:WaitForChild("Mai"))
local DoorSign = require(script.Parent:WaitForChild("DoorSign"))
local WornTags = require(script.Parent:WaitForChild("WornTags"))
local RoomAt = require(script.Parent:WaitForChild("RoomAt"))
local RaidLog = require(script.Parent:WaitForChild("RaidLog"))
local Terminal = require(script.Parent:WaitForChild("Terminal"))

local GetState = Remotes:WaitForChild("GetState") :: RemoteFunction
local SetDoorsOpen = Remotes:WaitForChild("SetDoorsOpen") :: RemoteEvent
local SellSpoils = Remotes:WaitForChild("SellSpoils") :: RemoteEvent
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent
local RaidFinished = Remotes:WaitForChild("RaidFinished") :: RemoteEvent
local DebugTravel = Remotes:WaitForChild("DebugTravel") :: RemoteEvent
local Refused = Remotes:WaitForChild("Refused") :: RemoteEvent

local EDGE = 16 -- gap between the HUD and the screen edge
local TELLING_SHARE = 0.75 -- a raid is told over most of the gap before the next party, leaving a breath

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local screen = Instance.new("ScreenGui")
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.Parent = playerGui

local currentOutlook: Types.Outlook? = nil
local lineCount = 0 -- moves through each moment's lines, so the same line doesn't come twice in a row

local function nextVariant(): number
	lineCount += 1
	return lineCount
end
local currentState: Types.PlayerState? = nil -- names the room you're standing in

-- Top left: bronze, and the toggle that hides the big panels
local bronzePanel = Ui.panel(screen, 200, 8)
bronzePanel.Position = UDim2.fromOffset(EDGE, EDGE)
local bronzeLabel = Ui.text(bronzePanel, "… bronze", Ui.STYLES.money)

-- Top right: the door sign, hanging from the top edge. Mai says what the doors mean
local signHolder = Ui.group(screen, 0)
signHolder.AnchorPoint = Vector2.new(1, 0)
signHolder.Position = UDim2.new(1, -EDGE, 0, 0)
signHolder.Size = UDim2.fromOffset(160, 0)
DoorSign.create(signHolder, function(open: boolean)
	SetDoorsOpen:FireServer(open)
	Mai.say(Lines.doors(open, nextVariant()), not open)
end)

-- Top centre: the room you're standing in, only while you're in one
local nameplate = Ui.text(screen, "", Ui.STYLES.heading)
nameplate.AnchorPoint = Vector2.new(0.5, 0)
nameplate.Position = UDim2.new(0.5, 0, 0, EDGE)
nameplate.Size = UDim2.fromOffset(400, 0)
nameplate.TextXAlignment = Enum.TextXAlignment.Center
nameplate.Visible = false

-- Bottom right: a tag per worn room, with its fix cost
local wornTags = Ui.group(screen, 4)
wornTags.AnchorPoint = Vector2.new(1, 1)
wornTags.Position = UDim2.new(1, -EDGE, 1, -EDGE)
wornTags.Size = UDim2.fromOffset(320, 0)

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

local function render(state: Types.PlayerState, outlook: Types.Outlook)
	currentState = state
	currentOutlook = outlook
	bronzeLabel.Text = `{state.bronze} bronze`
	WornTags.render(wornTags, state)
	RoomPanel.render(roomRows, state)
	Terminal.render(state, outlook)
end

local function nameplateText(): string?
	local state, character = currentState, Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local dungeon = RoomAt.dungeonOf(Players.LocalPlayer.UserId, workspace)
	if not (state and root and root:IsA("BasePart") and dungeon) then
		return nil
	end
	local slot = RoomAt.slotAt(dungeon, root.Position)
	local segment = if slot then state.dungeon.segments[slot] else nil
	return if segment then Catalog.rooms[segment.kind].displayName else nil
end

-- Mai announces the party as the telling starts. How it went (her line, the ledger row)
-- waits until it's told, so the result isn't spoiled
local function onRaidFinished(events: { Types.RaidEvent }, report: Types.RaidReport)
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
Refused.OnClientEvent:Connect(function(reason: Types.Refusal)
	Mai.say(Lines.refusal(reason, nextVariant()))
end)

local initialState, initialOutlook = GetState:InvokeServer()
if initialState and initialOutlook then
	render(initialState :: Types.PlayerState, initialOutlook :: Types.Outlook)
end

task.spawn(function()
	while true do
		local text = nameplateText()
		nameplate.Visible = text ~= nil
		nameplate.Text = text or ""
		task.wait(0.25)
	end
end)
