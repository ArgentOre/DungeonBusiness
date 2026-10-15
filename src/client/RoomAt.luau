--!strict
-- Which of a dungeon's rooms a point is over, if any. The hallway and the hub are no room.
local function isOver(floor: BasePart, position: Vector3): boolean
	local offset = floor.CFrame:PointToObjectSpace(position)
	return math.abs(offset.X) <= floor.Size.X / 2 and math.abs(offset.Z) <= floor.Size.Z / 2
end

-- The room's slot, from the "Slot" attribute the server puts on each room
local function slotAt(dungeon: Model, position: Vector3): number?
	for _, room in dungeon:GetChildren() do
		local slot = room:GetAttribute("Slot")
		local floor = if room:IsA("Model") then room.PrimaryPart else nil
		if typeof(slot) == "number" and floor and isOver(floor, position) then
			return slot
		end
	end
	return nil
end

-- The player's own dungeon, by the owner the server marks it with
local function dungeonOf(userId: number, world: Instance): Model?
	for _, child in world:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("OwnerUserId") == userId then
			return child
		end
	end
	return nil
end

return {
	slotAt = slotAt,
	dungeonOf = dungeonOf,
}
