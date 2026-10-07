--!strict
-- The cleanup HUD: bronze, the raid button, the dungeon's rooms, and the raid log.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Types = require(Shared:WaitForChild("Types"))
local Rules = require(Shared:WaitForChild("Rules"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local EventText = require(Shared:WaitForChild("EventText"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local RaidReportView = require(script.Parent:WaitForChild("RaidReportView"))

local GetState = Remotes:WaitForChild("GetState") :: RemoteFunction
local StartRaid = Remotes:WaitForChild("StartRaid") :: RemoteEvent
local Repair = Remotes:WaitForChild("Repair") :: RemoteEvent
local BuyMob = Remotes:WaitForChild("BuyMob") :: RemoteEvent
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent
local RaidFinished = Remotes:WaitForChild("RaidFinished") :: RemoteEvent

local EDGE = 16 -- gap between the HUD and the screen edge

local function hireableKinds(): { Types.MobKind }
	local kinds: { Types.MobKind } = {}
	for kind: Types.MobKind, stats in Catalog.mobs do
		if stats.hireCost then
			table.insert(kinds, kind)
		end
	end
	table.sort(kinds) -- Catalog.mobs is a dictionary, so its order isn't stable
	return kinds
end

local HIREABLE = table.freeze(hireableKinds())

local screen = Instance.new("ScreenGui")
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local currentState: Types.PlayerState? = nil

-- Top left: bronze, and the toggle that hides the big panels
local bronzePanel = Ui.panel(screen, 200, 8)
bronzePanel.Position = UDim2.fromOffset(EDGE, EDGE)
local bronzeLabel = Ui.text(bronzePanel, "… bronze", Ui.STYLES.money)

-- Top right: the one main action
local raidColumn = Instance.new("Frame")
raidColumn.AnchorPoint = Vector2.new(1, 0)
raidColumn.Position = UDim2.new(1, -EDGE, 0, EDGE)
raidColumn.Size = UDim2.fromOffset(220, 52)
raidColumn.BackgroundTransparency = 1
raidColumn.Parent = screen
Ui.primaryButton(raidColumn, "Open the doors", function()
	StartRaid:FireServer()
end)

-- Bottom left: the rooms
local dungeonPanel = Ui.panel(screen, 340, 12)
dungeonPanel.AnchorPoint = Vector2.new(0, 1)
dungeonPanel.Position = UDim2.new(0, EDGE, 1, -EDGE)
Ui.text(dungeonPanel, "Your dungeon", Ui.STYLES.label)
local roomRows = Ui.group(dungeonPanel, 14)

-- Bottom right: the raid log, opened from the raid report
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

local function repairButtonText(segment: Types.Segment, points: number): string
	if segment.condition >= 100 then
		return "Spotless"
	end
	if points == 0 then
		return "Repair (not enough bronze)"
	end
	return `Repair +{points} · {Rules.repairCost(segment, points)} bronze`
end

local function addRepairButton(row: Frame, state: Types.PlayerState, slot: number)
	local points = Rules.affordableRepair(state, slot)
	local segment = state.dungeon.segments[slot]
	local button = Ui.secondaryButton(row, repairButtonText(segment, points), function()
		if points > 0 then
			Repair:FireServer(slot, points)
		end
	end)
	if points == 0 then
		Ui.disable(button)
	end
end

local function addHireButton(row: Frame, state: Types.PlayerState, slot: number, kind: Types.MobKind)
	local stats = Catalog.mobs[kind]
	local allowed = Rules.canBuyMob(state, slot, kind)
	local button = Ui.secondaryButton(row, `Hire {stats.displayName} · {stats.hireCost} bronze`, function()
		if allowed then
			BuyMob:FireServer(slot, kind)
		end
	end)
	if not allowed then
		Ui.disable(button)
	end
end

local function roomTitle(segment: Types.Segment, slot: number): string
	local stats = Catalog.rooms[segment.kind]
	local staff = if stats.mobSlots > 0 then `   staff {#segment.mobs}/{stats.mobSlots}` else ""
	return `{slot} · {stats.displayName}{staff}`
end

local function addRoomRow(state: Types.PlayerState, slot: number)
	local segment = state.dungeon.segments[slot]
	local row = Ui.group(roomRows, 6)
	Ui.text(row, roomTitle(segment, slot), Ui.STYLES.label)
	local worn = segment.condition < 100
	Ui.bar(row, segment.condition / 100, if worn then Ui.THEME.needsFix else Ui.THEME.mutedText)
	if Catalog.rooms[segment.kind].repairInWorld then
		Ui.text(row, `{segment.condition}% · fix it in the room`, Ui.STYLES.muted)
	else
		addRepairButton(row, state, slot)
	end
	if Rules.hasFreeSlot(segment) then
		for _, kind: Types.MobKind in HIREABLE do
			addHireButton(row, state, slot, kind)
		end
	end
end

local function render(state: Types.PlayerState)
	currentState = state
	bronzeLabel.Text = `{state.bronze} bronze`
	Ui.clear(roomRows)
	for slot in state.dungeon.segments do
		addRoomRow(state, slot)
	end
end

local function fillLog(events: { Types.RaidEvent })
	Ui.clear(logLines)
	for _, event in events do
		Ui.text(logLines, EventText.format(event), Ui.STYLES.muted)
	end
end

local function showLog()
	logPanel.Visible = true
end

local function onRaidFinished(events: { Types.RaidEvent }, report: Types.RaidReport)
	fillLog(events)
	logPanel.Visible = false
	if currentState then
		RaidReportView.show(screen, report, currentState, showLog)
	end
end

StateChanged.OnClientEvent:Connect(render)
RaidFinished.OnClientEvent:Connect(onRaidFinished)

local initialState = GetState:InvokeServer() :: Types.PlayerState?
if initialState then
	render(initialState)
end
