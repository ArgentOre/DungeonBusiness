--!strict
local Types = require(script.Parent.Types)

local TEMPLATES: { [Types.RaidEventKind]: string } = table.freeze({
	EnterRoom = "Room %d: the party walks in",
	TrapHit = "Room %d: the trap hits the party for %d",
	MobHit = "Room %d: your monsters hit the party for %d",
	MobDefeated = "Room %d: one of your monsters is knocked out",
	RoomDamaged = "Room %d: the room takes %d wear",
	PartyDefeated = "Room %d: the party is defeated!",
	PartyEscaped = "Room %d: the party escapes with treasure!",
})

local function format(event: Types.RaidEvent): string
	return string.format(TEMPLATES[event.kind], event.slot, event.amount or 0)
end

return {
	format = format,
}
