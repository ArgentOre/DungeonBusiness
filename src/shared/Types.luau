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
	hp: number,
	power: number,
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
}

export type RaidReport = {
	won: boolean,
	rookies: boolean, -- the chest was empty, so only rookies came
	spoilsDropped: number,
	wagesPaid: number,
	endSlot: number, -- room where the party was defeated, or the last room if it escaped
	treasureTaken: number,
	reputation: number, -- how famous the dungeon was when this party came
}

export type RoomStats = {
	displayName: string,
	trapDamage: number,
	mobSlots: number,
	wearPerRaid: number,
	repairCostPerPoint: number,
	repairInWorld: boolean, -- repaired by walking to it, not from the panel (Milestone 1, step 1a)
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