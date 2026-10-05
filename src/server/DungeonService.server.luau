--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = ReplicatedStorage.Remotes
local Types = require(Shared.Types)
local Rules = require(Shared.Rules)
local Catalog = require(Shared.Catalog)
local Logic = script.Parent.logic
local StartingState = require(Logic.StartingState)
local PlayRaid = require(Logic.PlayRaid)
local Repair = require(Logic.Repair)
local Hire = require(Logic.Hire)

local states: { [Player]: Types.PlayerState } = {}
local lastRaidAt: { [Player]: number } = {}
local rng = Random.new()

local function setState(player: Player, state: Types.PlayerState)
	states[player] = state
	Remotes.StateChanged:FireClient(player, state)
end

local function onPlayerAdded(player: Player)
	states[player] = StartingState.create()
end

local function onPlayerRemoving(player: Player)
	states[player] = nil
	lastRaidAt[player] = nil
end

local function onGetState(player: Player): Types.PlayerState?
	return states[player]
end

local function raidOnCooldown(player: Player): boolean
	local last = lastRaidAt[player]
	return last ~= nil and os.clock() - last < Catalog.economy.raidCooldownSeconds
end

local function onStartRaid(player: Player)
	local state = states[player]
	if not state or raidOnCooldown(player) then
		return
	end
	lastRaidAt[player] = os.clock()
	local newState, result = PlayRaid.play(state, rng)
	setState(player, newState)
	Remotes.RaidFinished:FireClient(player, result.events, result.won)
end

local function onRepair(player: Player, slot: unknown, points: unknown)
	local state = states[player]
	if not state or typeof(slot) ~= "number" or typeof(points) ~= "number" then
		return
	end
	if not Rules.canRepair(state, slot, points) then
		return
	end
	setState(player, Repair.apply(state, slot, points))
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

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Remotes.GetState.OnServerInvoke = onGetState
Remotes.StartRaid.OnServerEvent:Connect(onStartRaid)
Remotes.Repair.OnServerEvent:Connect(onRepair)
Remotes.BuyMob.OnServerEvent:Connect(onBuyMob)
