--!strict
-- Turns a Dungeon into a Model in the world. The origin is the hallway entrance:
-- the hallway runs along +X from it, and rooms sit on its +Z side in raid order,
-- each room's doorway (north wall) facing the hallway.
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)

local RoomTemplates = ServerStorage.RoomTemplates

local ROOM_SIZE = 72
local ROOM_SPACING = 82 -- matches how Jordan laid the templates out side by side
local HALLWAY_WIDTH = 20
local ENTRANCE_LENGTH = 12 -- hallway before the first doorway, where the player arrives
local REARM_HOLD_SECONDS = 1.5
local REARM_PROMPT_DISTANCE = 10

local function findFloor(room: Model): BasePart
	local structure = room:FindFirstChild("Structure")
	local floor = structure and structure:FindFirstChild("Floor")
	assert(floor and floor:IsA("BasePart"), `Room template {room.Name} needs Structure.Floor`)
	return floor
end

local function cloneRoom(kind: Types.RoomKind): Model
	local template = RoomTemplates:FindFirstChild(kind)
	assert(template and template:IsA("Model"), `No room template named {kind}`)
	local room = template:Clone()
	room.PrimaryPart = findFloor(room)
	return room
end

local function findTrap(room: Model): Instance
	local gameplay = room:FindFirstChild("Gameplay")
	local trap = gameplay and gameplay:FindFirstChild("Trap")
	assert(trap, `Room template {room.Name} needs Gameplay.Trap`)
	return trap
end

local function isSprung(segment: Types.Segment): boolean
	return segment.condition < 100
end

local function removeUnusedTrapState(trap: Instance, sprung: boolean)
	local unused = trap:FindFirstChild(if sprung then "Armed" else "Sprung")
	assert(unused, "Gameplay.Trap needs both Armed and Sprung")
	unused:Destroy()
end

local function addRearmPrompt(trap: Instance, slot: number)
	local spot = trap:FindFirstChild("RepairSpot")
	assert(spot and spot:IsA("BasePart"), "Gameplay.Trap needs a RepairSpot part")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RearmPrompt"
	prompt.ActionText = "Re-arm"
	prompt.ObjectText = "Trap"
	prompt.HoldDuration = REARM_HOLD_SECONDS
	prompt.MaxActivationDistance = REARM_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false -- RepairSpot sits inside the trap's own parts
	prompt:SetAttribute("RepairSlot", slot)
	prompt.Parent = spot
end

local function setUpTrap(room: Model, segment: Types.Segment, slot: number)
	local trap = findTrap(room)
	local sprung = isSprung(segment)
	removeUnusedTrapState(trap, sprung)
	if sprung then
		addRearmPrompt(trap, slot)
	end
end

local function roomCenterX(slot: number): number
	return ENTRANCE_LENGTH + ROOM_SIZE / 2 + (slot - 1) * ROOM_SPACING
end

-- Placeholder until Jordan builds a hallway piece
local function makeHallway(origin: CFrame, roomCount: number): Part
	local length = roomCenterX(roomCount) + ROOM_SIZE / 2
	local hallway = Instance.new("Part")
	hallway.Name = "Hallway"
	hallway.Anchored = true
	hallway.Size = Vector3.new(length, 1, HALLWAY_WIDTH)
	hallway.CFrame = origin * CFrame.new(length / 2, -0.5, 0)
	return hallway
end

local function build(dungeon: Types.Dungeon, origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Dungeon"
	local roomCenterZ = HALLWAY_WIDTH / 2 + ROOM_SIZE / 2
	for slot, segment in dungeon.segments do
		local room = cloneRoom(segment.kind)
		room.Name = `{slot} {segment.kind}`
		if Catalog.rooms[segment.kind].repairInWorld then
			setUpTrap(room, segment, slot)
		end
		room:PivotTo(origin * CFrame.new(roomCenterX(slot), -0.5, roomCenterZ))
		room.Parent = model
	end
	makeHallway(origin, #dungeon.segments).Parent = model
	return model
end

return {
	build = build,
}
