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
	dungeon: Dungeon,
}

export type Party = {
	hp: number,
	power: number,
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

export type RoomStats = {
	trapDamage: number,
	mobSlots: number,
	wearPerRaid: number,
	repairCostPerPoint: number,
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