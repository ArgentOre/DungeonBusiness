--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Types = require(Shared:WaitForChild("Types"))
local Rules = require(Shared:WaitForChild("Rules"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local EventText = require(Shared:WaitForChild("EventText"))

local GetState = Remotes:WaitForChild("GetState") :: RemoteFunction
local StartRaid = Remotes:WaitForChild("StartRaid") :: RemoteEvent
local Repair = Remotes:WaitForChild("Repair") :: RemoteEvent
local BuyMob = Remotes:WaitForChild("BuyMob") :: RemoteEvent
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent
local RaidFinished = Remotes:WaitForChild("RaidFinished") :: RemoteEvent

local BUTTON_HEIGHT = 48

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

local function makeLabel(parent: Instance, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	label.TextScaled = true
	label.Text = text
	label.LayoutOrder = #parent:GetChildren()
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, text: string, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	button.TextScaled = true
	button.Text = text
	button.Activated:Connect(onClick)
	button.LayoutOrder = #parent:GetChildren()
	button.Parent = parent
	return button
end

local function makePanel(parent: Instance, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Position = position
	frame.Size = size
	frame.BackgroundTransparency = 0.3
	frame.LayoutOrder = #parent:GetChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	frame.Parent = parent
	return frame
end

local function clearItems(panel: Instance)
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local screen = Instance.new("ScreenGui")
screen.ResetOnSpawn = false
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local controls = makePanel(screen, UDim2.fromScale(0.02, 0.1), UDim2.fromScale(0.35, 0.8))
local logPanel = makePanel(screen, UDim2.fromScale(0.4, 0.1), UDim2.fromScale(0.55, 0.8))
local bronzeLabel = makeLabel(controls, "Bronze: ...")
makeButton(controls, "Open the doors (start raid)", function()
	StartRaid:FireServer()
end)
local roomButtons = makePanel(controls, UDim2.new(), UDim2.fromScale(1, 0))
roomButtons.AutomaticSize = Enum.AutomaticSize.Y
roomButtons.BackgroundTransparency = 1

local function repairText(state: Types.PlayerState, slot: number): string
	local segment = state.dungeon.segments[slot]
	local points = Rules.affordableRepair(state, slot)
	local cost = Rules.repairCost(segment, points)
	local staff = `{#segment.mobs}/{Catalog.rooms[segment.kind].mobSlots}`
	return `Room {slot} {segment.kind}: {segment.condition}% | staff {staff} | repair +{points} for {cost}`
end

local function makeHireButton(state: Types.PlayerState, slot: number, kind: Types.MobKind)
	local stats = Catalog.mobs[kind]
	local allowed = Rules.canBuyMob(state, slot, kind)
	local button = makeButton(roomButtons, `   Hire {stats.displayName} ({stats.hireCost})`, function()
		if allowed then
			BuyMob:FireServer(slot, kind)
		end
	end)
	if not allowed then
		button.AutoButtonColor = false
		button.TextTransparency = 0.6
	end
end

local function renderRooms(state: Types.PlayerState)
	clearItems(roomButtons)
	for slot, segment in state.dungeon.segments do
		makeButton(roomButtons, repairText(state, slot), function()
			Repair:FireServer(slot, Rules.affordableRepair(state, slot))
		end)
		if Rules.hasFreeSlot(segment) then
			for _, kind: Types.MobKind in HIREABLE do
				makeHireButton(state, slot, kind)
			end
		end
	end
end

local function render(state: Types.PlayerState)
	bronzeLabel.Text = `Bronze: {state.bronze}`
	renderRooms(state)
end

local function showLog(events: { Types.RaidEvent }, won: boolean)
	clearItems(logPanel)
	makeLabel(logPanel, if won then "Raid result: the dungeon held!" else "Raid result: the party got away!")
	for _, event in events do
		makeLabel(logPanel, EventText.format(event)).Size = UDim2.new(1, 0, 0, 22)
	end
end

StateChanged.OnClientEvent:Connect(render)
RaidFinished.OnClientEvent:Connect(showLog)

local initialState = GetState:InvokeServer() :: Types.PlayerState?
if initialState then
	render(initialState)
end
