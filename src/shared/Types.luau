--!strict

export type RoomKind = "TrapRoom" | "Crypt" | "TreasureRoom"
export type MobKind = "Skeleton" | "Slime" | "BoneLord"

export type Mob = {
	kind: MobKind,
}

export type Segment = {
	kind: RoomKind,
	condition: number, -- integer 0–100; Repair keeps it in range
	mobs: { Mob },
}

export type Dungeon = {
	segments: { Segment },
}

export type PlayerState = {
	bronze: number,
	treasure: number, -- value stocked in the treasure room: the lure. With none, only rookies come
	spoils: number, -- value of what defeated adventurers left behind, waiting to be sold or stocked
	reputation: number, -- raids held in a row (capped). Word spreads, and stronger parties come
	dungeon: Dungeon,
}

export type Party = {
	power: number, -- also the party's starting HP
	strength: number, -- 1 for a full party; rookies are weaker and clumsier, so they wear rooms less; a famous dungeon draws stronger
}

export type RaidEventKind =
	"EnterRoom"
	| "TrapHit"
	| "MobHit"
	| "MobDefeated"
	| "RoomDamaged"
	| "PartyDefeated"
	| "PartyEscaped"

export type RaidEvent = {
	kind: RaidEventKind,
	slot: number,
	amount: number?,
}

export type RaidResult = {
	won: boolean,
	events: { RaidEvent },
	after: Dungeon,
	loot: number,
	party: Party, -- who came, so the raid can be replayed against other rooms
}

export type RaidReport = {
	won: boolean,
	rookies: boolean, -- the chest was empty, so only rookies came
	spoilsDropped: number,
	wagesPaid: number,
	endSlot: number, -- room where the party was defeated, or the last room if it escaped
	treasureTaken: number,
	reputation: number, -- how famous the dungeon was when this party came
	fixingWouldHaveHeld: boolean, -- the party escaped, but fully fixed rooms would have stopped it
	partyPower: number, -- how strong the party was; players read it as a rank
}

-- A rank is a reading of power, so players compare letters, never numbers
export type Rank = {
	letter: string,
	minPower: number,
}

-- The one thing that best explains a raid (nil for a plain win: nothing to explain)
export type RaidCause = "WornRooms" | "Rookies" | "Fame" | "TooTough"

-- Mai's moods: each has its own portrait and line tone
export type Mood = "Relaxed" | "Alert" | "Worried" | "Pleased" | "Sheepish"

-- What's coming against what the dungeon holds, compared as ranks
export type Verdict = "Safe" | "Close" | "Danger"

-- What the administrator can see coming, as powers; the client shows them as ranks
export type Outlook = {
	holds: number, -- the strongest party the dungeon stops as it stands
	holdsFixed: number, -- the same, with every room fixed: what fixing is worth
	coming: number, -- a typical next party, before luck
}

export type RoomStats = {
	displayName: string,
	trapDamage: number,
	mobSlots: number,
	wearPerRaid: number,
	repairCostPerPoint: number,
	holdsTreasure: boolean, -- where the dungeon's treasure and spoils are kept
}

export type MobStats = {
	maxHp: number,
	damage: number,
	wage: number,
	hireCost: number?, -- nil means it can't be bought
	displayName: string,
}

export type StarterSegment = {
	kind: RoomKind,
	mobs: { MobKind },
}

return {}