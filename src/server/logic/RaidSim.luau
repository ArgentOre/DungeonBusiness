--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)

type Events = { Types.RaidEvent }

local function addEvent(events: Events, event: Types.RaidEvent)
	table.insert(events, event)
end

local function effectiveness(segment: Types.Segment): number
	return segment.condition / 100
end

local function springTrap(segment: Types.Segment, slot: number, partyHp: number, events: Events): number
	local damage = math.round(Catalog.rooms[segment.kind].trapDamage * effectiveness(segment))
	if damage > 0 then
		addEvent(events, { kind = "TrapHit", slot = slot, amount = damage })
	end
	return partyHp - damage
end

local function mobsDamage(mobs: { Types.Mob }, from: number): number
	local total = 0
	for i = from, #mobs do
		total += Catalog.mobs[mobs[i].kind].damage
	end
	return total
end

local function fightMobs(segment: Types.Segment, slot: number, party: Types.Party, partyHp: number, events: Events): number
	local mobs = segment.mobs
	local front = 1
	local frontHp = if #mobs > 0 then Catalog.mobs[mobs[1].kind].maxHp else 0
	while partyHp > 0 and front <= #mobs do
		local damage = math.round(mobsDamage(mobs, front) * effectiveness(segment))
		partyHp -= damage
		addEvent(events, { kind = "MobHit", slot = slot, amount = damage })
		frontHp -= party.power
		if frontHp <= 0 then
			addEvent(events, { kind = "MobDefeated", slot = slot })
			front += 1
			frontHp = if front <= #mobs then Catalog.mobs[mobs[front].kind].maxHp else 0
		end
	end
	return partyHp
end

local function runSegment(segment: Types.Segment, slot: number, party: Types.Party, partyHp: number, events: Events): (number, Types.Segment)
	addEvent(events, { kind = "EnterRoom", slot = slot })
	partyHp = springTrap(segment, slot, partyHp, events)
	partyHp = fightMobs(segment, slot, party, partyHp, events)
	local wear = math.round(Catalog.rooms[segment.kind].wearPerRaid * party.strength)
	addEvent(events, { kind = "RoomDamaged", slot = slot, amount = wear })
	return partyHp, { kind = segment.kind, condition = math.max(0, segment.condition - wear), mobs = segment.mobs }
end

local function simulate(dungeon: Types.Dungeon, party: Types.Party): Types.RaidResult
	local events: Events = {}
	local after: { Types.Segment } = {}
	local partyHp = party.hp
	for slot, segment in dungeon.segments do
		if partyHp <= 0 then
			table.insert(after, segment)
			continue
		end
		local updated
		partyHp, updated = runSegment(segment, slot, party, partyHp, events)
		table.insert(after, updated)
		if partyHp <= 0 then
			addEvent(events, { kind = "PartyDefeated", slot = slot })
		end
	end
	local won = partyHp <= 0
	if not won then
		addEvent(events, { kind = "PartyEscaped", slot = #dungeon.segments })
	end
	return {
		won = won,
		events = events,
		after = { segments = after },
		loot = math.round(party.power * Catalog.party.lootPerPower),
	}
end

return {
	simulate = simulate,
}