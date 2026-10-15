--!strict
-- Gives each player a plot and keeps their dungeon Model there. Players spawn in the hub
-- (Roblox's SpawnLocation); travel to the dungeon is a separate step.
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local DungeonBuilder = require(script.Parent.DungeonBuilder)

-- Open space past a default 2048-stud baseplate and away from the hub, until the hub has bays
local FIRST_PLOT = CFrame.new(2000, 0, 0)
local PLOT_SPACING = 200 -- along Z; a dungeon is about 100 studs deep
local SPAWN_HEIGHT = 4

type Plot = {
	index: number,
	model: Model?,
	shown: Types.Dungeon?, -- what `model` currently shows
}

local plots: { [Player]: Plot } = {}

local function plotOrigin(index: number): CFrame
	return FIRST_PLOT * CFrame.new(0, 0, (index - 1) * PLOT_SPACING)
end

local function isTaken(index: number): boolean
	for _, plot in plots do
		if plot.index == index then
			return true
		end
	end
	return false
end

local function firstFreeIndex(): number
	local index = 1
	while isTaken(index) do
		index += 1
	end
	return index
end

local function moveToEntrance(character: Model, index: number)
	character:WaitForChild("HumanoidRootPart")
	-- Face +X, down the hallway
	local facing = CFrame.lookAt(Vector3.zero, Vector3.xAxis)
	character:PivotTo(plotOrigin(index) * CFrame.new(0, SPAWN_HEIGHT, 0) * facing)
end

local function claim(player: Player)
	plots[player] = { index = firstFreeIndex(), model = nil, shown = nil }
end

-- Puts the player at their dungeon's entrance, if they have a plot and a character
local function sendToDungeon(player: Player)
	local plot, character = plots[player], player.Character
	if plot and character then
		moveToEntrance(character, plot.index)
	end
end

local function rebuild(player: Player, plot: Plot, dungeon: Types.Dungeon)
	local oldModel = plot.model
	local model = DungeonBuilder.build(dungeon, plotOrigin(plot.index))
	model.Name = `{player.Name}'s Dungeon`
	model:SetAttribute("OwnerUserId", player.UserId) -- how a client finds its own dungeon
	model.Parent = workspace
	plot.model = model
	-- Destroy the old dungeon only after the new one is in place, so a player
	-- standing in a room never loses the floor under them during a rebuild
	if oldModel then
		oldModel:Destroy()
	end
end

-- Most changes only touch a few rooms, so update in place; a full rebuild makes the world flash
local function show(player: Player, dungeon: Types.Dungeon)
	local plot = plots[player]
	if not plot then
		return
	end
	local model, shown = plot.model, plot.shown
	if not (model and shown and DungeonBuilder.update(model, shown, dungeon)) then
		rebuild(player, plot, dungeon)
	end
	plot.shown = dungeon
end

local function owns(player: Player, instance: Instance): boolean
	local plot = plots[player]
	local model = if plot then plot.model else nil
	return model ~= nil and instance:IsDescendantOf(model)
end

local function release(player: Player)
	local plot = plots[player]
	if not plot then
		return
	end
	if plot.model then
		plot.model:Destroy()
	end
	plots[player] = nil
end

return {
	claim = claim,
	sendToDungeon = sendToDungeon,
	show = show,
	owns = owns,
	release = release,
}
