--!strict
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Remotes = ReplicatedStorage.Remotes
local Types = require(Shared.Types)
local Rules = require(Shared.Rules)
local Catalog = require(Shared.Catalog)
local Logic = script.Parent.logic
local StartingState = require(Logic.StartingState)
local PlayRaid = require(Logic.PlayRaid)
local RaidReport = require(Logic.RaidReport)
local Repair = require(Logic.Repair)
local Spoils = require(Logic.Spoils)
local Hire = require(Logic.Hire)
local Outlook = require(Logic.Outlook)
local PlotService = require(script.Parent.PlotService)
local HubDesk = require(script.Parent.HubDesk)

local states: { [Player]: Types.PlayerState } = {}
local lastRaidAt: { [Player]: number } = {}
local doorsOpen: { [Player]: true } = {}
local rng = Random.new()

local function setState(player: Player, state: Types.PlayerState)
	states[player] = state
	PlotService.show(player, state.dungeon, state.treasure)
	Remotes.StateChanged:FireClient(player, state, Outlook.of(state))
end

local function onPlayerAdded(player: Player)
	local state = StartingState.create()
	states[player] = state
	PlotService.claim(player)
	PlotService.show(player, state.dungeon, state.treasure)
end

local function onPlayerRemoving(player: Player)
	states[player] = nil
	lastRaidAt[player] = nil
	doorsOpen[player] = nil
	PlotService.release(player)
end

local function onGetState(player: Player): (Types.PlayerState?, Types.Outlook?)
	local state = states[player]
	return state, if state then Outlook.of(state) else nil
end

-- The interval is enforced here, not by the loop, so toggling the doors can't speed up raids
local function partyIsDue(player: Player): boolean
	local now = os.clock()
	return Rules.nextPartyAt(lastRaidAt[player], now) <= now
end

local function runRaid(player: Player)
	local state = states[player]
	if not state or not partyIsDue(player) then
		return
	end
	lastRaidAt[player] = os.clock()
	local newState, result = PlayRaid.play(state, rng)
	setState(player, newState)
	Remotes.RaidFinished:FireClient(player, result.events, RaidReport.make(state, newState, result))
end

local function onSetDoorsOpen(player: Player, open: unknown)
	if typeof(open) ~= "boolean" then
		return
	end
	if open then
		doorsOpen[player] = true
		runRaid(player)
	else
		doorsOpen[player] = nil
	end
end

local function runDueRaids()
	for player in doorsOpen do
		runRaid(player)
	end
end

local function tryRepair(player: Player, slot: number, points: number)
	local state = states[player]
	if not state or not Rules.canRepair(state, slot, points) then
		return
	end
	setState(player, Repair.apply(state, slot, points))
end

local function onFixPrompt(player: Player, state: Types.PlayerState, slot: number)
	local refusal = Rules.fixRefusal(state, slot)
	if refusal then
		Remotes.Refused:FireClient(player, refusal)
		return
	end
	tryRepair(player, slot, Rules.affordableRepair(state, slot))
end

-- Stocks every spoil that fits; the amount is the server's, not the client's
local function onStockPrompt(player: Player, state: Types.PlayerState)
	local refusal = Rules.stockRefusal(state)
	if refusal then
		Remotes.Refused:FireClient(player, refusal)
		return
	end
	local amount = Rules.stockable(state)
	if Rules.canStock(state, amount) then
		setState(player, Spoils.stock(state, amount))
	end
end

-- Prompts in the player's own dungeon: fixing a room, or stocking the vault
local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
	local state = states[player]
	if not state or not PlotService.owns(player, prompt) then
		return
	end
	local slot: unknown = prompt:GetAttribute("RepairSlot")
	if typeof(slot) == "number" then
		onFixPrompt(player, state, slot)
	elseif prompt.Name == Catalog.vault.promptName then
		onStockPrompt(player, state)
	end
end

local function onSellSpoils(player: Player, amount: unknown)
	local state = states[player]
	if not state or typeof(amount) ~= "number" or not Rules.canSell(state, amount) then
		return
	end
	setState(player, Spoils.sell(state, amount))
end

-- Admin debug tool, Studio only: until real travel exists (conveyors, Milestone 2), a button
-- moves you between the hub and your dungeon. "Hub" respawns you at the hub's SpawnLocation,
-- so no hub position lives in code
local function onDebugTravel(player: Player, destination: unknown)
	if not RunService:IsStudio() then
		return
	end
	if destination == "Dungeon" then
		PlotService.sendToDungeon(player)
	elseif destination == "Hub" then
		player:LoadCharacter()
	end
end

local function toMobKind(name: string): Types.MobKind?
	for kind: Types.MobKind in Catalog.mobs do
		if kind == name then
			return kind
		end
	end
	return nil
end

local function onBuyMob(player: Player, slot: unknown, name: unknown)
	local state = states[player]
	if not state or typeof(slot) ~= "number" or typeof(name) ~= "string" then
		return
	end
	local kind: Types.MobKind? = toMobKind(name)
	if not kind or not Rules.canBuyMob(state, slot, kind) then
		return
	end
	setState(player, Hire.apply(state, slot, kind))
end

HubDesk.addTerminalPrompts(workspace:WaitForChild("World"):WaitForChild("Hub"))

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Remotes.GetState.OnServerInvoke = onGetState
Remotes.SetDoorsOpen.OnServerEvent:Connect(onSetDoorsOpen)
Remotes.BuyMob.OnServerEvent:Connect(onBuyMob)
Remotes.SellSpoils.OnServerEvent:Connect(onSellSpoils)
Remotes.DebugTravel.OnServerEvent:Connect(onDebugTravel)
ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)

task.spawn(function()
	while true do
		task.wait(1)
		runDueRaids()
	end
end)
