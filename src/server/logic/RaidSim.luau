--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)
local Condition = require(script.Parent.Condition)

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

local function startingHps(mobs: { Types.Mob }): { number }
	local hps = {}
	for i, mob in mobs do
		hps[i] = Catalog.mobs[mob.kind].maxHp
	end
	return hps
end

-- Mobs attack together but fall one at a time: every mob still standing hits the
-- party each round, and the party strikes the one at the front
local function fightMobs(segment: Types.Segment, slot: number, party: Types.Party, partyHp: number, events: Events): number
	local hps = startingHps(segment.mobs)
	local front = 1
	while partyHp > 0 and front <= #hps do
		local damage = math.round(mobsDamage(segment.mobs, front) * effectiveness(segment))
		partyHp -= damage
		addEvent(events, { kind = "MobHit", slot = slot, amount = damage })
		hps[front] -= party.power
		if hps[front] <= 0 then
			addEvent(events, { kind = "MobDefeated", slot = slot })
			front += 1
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
	return partyHp, Condition.withCondition(segment, math.max(0, segment.condition - wear))
end

local function simulate(dungeon: Types.Dungeon, party: Types.Party): Types.RaidResult
	-- A fight ends when the party or the mobs fall. Mobs in a 0% room deal no damage,
	-- so the party must be able to hurt them, or fightMobs never returns.
	assert(party.power >= 1, "A party with no power could never finish a fight")
	local events: Events = {}
	local after: { Types.Segment } = {}
	local partyHp = party.power
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
		party = party,
	}
end

return {
	simulate = simulate,
}