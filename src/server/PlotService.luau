--!strict
-- Gives each player a plot, keeps their dungeon Model there, and spawns them at its entrance.
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
	spawnConnection: RBXScriptConnection,
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
	local index = firstFreeIndex()
	local spawnConnection = player.CharacterAdded:Connect(function(character)
		moveToEntrance(character, index)
	end)
	plots[player] = { index = index, model = nil, spawnConnection = spawnConnection }
	if player.Character then
		task.spawn(moveToEntrance, player.Character, index)
	end
end

local function show(player: Player, dungeon: Types.Dungeon)
	local plot = plots[player]
	if not plot then
		return
	end
	if plot.model then
		plot.model:Destroy()
	end
	local model = DungeonBuilder.build(dungeon, plotOrigin(plot.index))
	model.Name = `{player.Name}'s Dungeon`
	model.Parent = workspace
	plot.model = model
end

local function release(player: Player)
	local plot = plots[player]
	if not plot then
		return
	end
	plot.spawnConnection:Disconnect()
	if plot.model then
		plot.model:Destroy()
	end
	plots[player] = nil
end

return {
	claim = claim,
	show = show,
	release = release,
}
