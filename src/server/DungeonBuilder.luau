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

local function findGameplay(room: Model): Model
	local gameplay = room:FindFirstChild("Gameplay")
	assert(gameplay and gameplay:IsA("Model"), `Room template {room.Name} needs a Gameplay model`)
	return gameplay
end

local function findTemplate(kind: Types.RoomKind): Model
	local template = RoomTemplates:FindFirstChild(kind)
	assert(template and template:IsA("Model"), `No room template named {kind}`)
	return template
end

local function cloneRoom(kind: Types.RoomKind): Model
	local room = findTemplate(kind):Clone()
	room.PrimaryPart = findFloor(room)
	return room
end

local function roomName(slot: number, kind: Types.RoomKind): string
	return `{slot} {kind}`
end

-- Below full condition a room looks worn: its trap is sprung and its mess shows
local function isWorn(segment: Types.Segment): boolean
	return segment.condition < 100
end

-- A missing or incomplete trap is art still in progress, not a broken dungeon:
-- warn and build the room without it, so the rest of the dungeon still loads
local function findUsableTrap(gameplay: Model, roomLabel: string): Instance?
	local trap = gameplay:FindFirstChild("Trap")
	local spot = trap and trap:FindFirstChild("RepairSpot")
	if not (trap and trap:FindFirstChild("Armed") and trap:FindFirstChild("Sprung") and spot and spot:IsA("BasePart")) then
		warn(`{roomLabel}: needs Gameplay.Trap with Armed, Sprung and a RepairSpot part; built without a trap`)
		return nil
	end
	return trap
end

local function removeUnusedTrapState(trap: Instance, sprung: boolean)
	local unused = trap:FindFirstChild(if sprung then "Armed" else "Sprung")
	if unused then
		unused:Destroy()
	end
end

local function addRearmPrompt(trap: Instance, slot: number)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RearmPrompt"
	prompt.ActionText = "Re-arm"
	prompt.ObjectText = "Trap"
	prompt.HoldDuration = REARM_HOLD_SECONDS
	prompt.MaxActivationDistance = REARM_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false -- RepairSpot sits inside the trap's own parts
	prompt:SetAttribute("RepairSlot", slot)
	prompt.Parent = trap:FindFirstChild("RepairSpot")
end

local function setUpTrap(gameplay: Model, roomLabel: string, segment: Types.Segment, slot: number)
	local trap = findUsableTrap(gameplay, roomLabel)
	if not trap then
		return
	end
	local sprung = isWorn(segment)
	removeUnusedTrapState(trap, sprung)
	if sprung then
		addRearmPrompt(trap, slot)
	end
end

-- Mess is optional art: a room without it simply looks tidy, so no warning
local function removeMessIfTidy(gameplay: Model, segment: Types.Segment)
	local mess = gameplay:FindFirstChild("Mess")
	if mess and not isWorn(segment) then
		mess:Destroy()
	end
end

-- Makes a room's Gameplay parts match its segment: trap state, re-arm prompt, mess
local function dressGameplay(gameplay: Model, roomLabel: string, segment: Types.Segment, slot: number)
	if Catalog.rooms[segment.kind].repairInWorld then
		setUpTrap(gameplay, roomLabel, segment, slot)
	end
	removeMessIfTidy(gameplay, segment)
end

-- A fresh copy of the template's Gameplay, placed where it belongs in `room`
local function freshGameplay(room: Model, kind: Types.RoomKind): Model
	local template = findTemplate(kind)
	local original = findGameplay(template)
	local gameplay = original:Clone()
	local offset = findFloor(template).CFrame:ToObjectSpace(original:GetPivot())
	gameplay:PivotTo(findFloor(room).CFrame * offset)
	return gameplay
end

-- Swaps only the room's Gameplay; floor and walls stay, so nothing flashes and nobody falls
local function refreshRoom(room: Model, segment: Types.Segment, slot: number)
	local gameplay = freshGameplay(room, segment.kind)
	dressGameplay(gameplay, room.Name, segment, slot)
	local old = findGameplay(room)
	gameplay.Parent = room
	old:Destroy()
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
		room.Name = roomName(slot, segment.kind)
		dressGameplay(findGameplay(room), room.Name, segment, slot)
		room:PivotTo(origin * CFrame.new(roomCenterX(slot), -0.5, roomCenterZ))
		room.Parent = model
	end
	makeHallway(origin, #dungeon.segments).Parent = model
	return model
end

local function sameLayout(a: Types.Dungeon, b: Types.Dungeon): boolean
	if #a.segments ~= #b.segments then
		return false
	end
	for slot, segment in a.segments do
		if segment.kind ~= b.segments[slot].kind then
			return false
		end
	end
	return true
end

-- Brings an existing dungeon Model from `old` to `new` by refreshing only rooms whose look
-- changed. Returns false when rooms were added, removed or reordered, or when a room is
-- missing from the Model: either way the world doesn't match, so the caller rebuilds.
local function update(model: Model, old: Types.Dungeon, new: Types.Dungeon): boolean
	if not sameLayout(old, new) then
		return false
	end
	for slot, segment in new.segments do
		local room = model:FindFirstChild(roomName(slot, segment.kind))
		if not (room and room:IsA("Model")) then
			return false
		end
		if isWorn(old.segments[slot]) ~= isWorn(segment) then
			refreshRoom(room, segment, slot)
		end
	end
	return true
end

return {
	build = build,
	update = update,
}
