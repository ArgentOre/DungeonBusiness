--!strict
local Types = require(script.Parent.Types)

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
	kind: Types.RoomKind,
	mobs: { Types.MobKind },
}

local function deepFreeze<T>(value: T): T
	for _, child in value :: any do
		if type(child) == "table" then
			deepFreeze(child)
		end
	end
	table.freeze(value :: any)
	return value
end

local rooms: { [Types.RoomKind]: RoomStats } = {
	TrapRoom = { trapDamage = 10, mobSlots = 0, wearPerRaid = 25, repairCostPerPoint = 1 },
	Crypt = { trapDamage = 0, mobSlots = 3, wearPerRaid = 10, repairCostPerPoint = 1 },
	TreasureRoom = { trapDamage = 0, mobSlots = 1, wearPerRaid = 5, repairCostPerPoint = 2 },
}

local mobs: { [Types.MobKind]: MobStats } = {
	Skeleton = { displayName = "Skeleton", maxHp = 20, damage = 4, wage = 2, hireCost = 15 },
	Slime = { displayName = "Slime", maxHp = 30, damage = 2, wage = 1, hireCost = 10 },
	BoneLord = { displayName = "Sir Rattleford", maxHp = 120, damage = 10, wage = 8, hireCost = nil },
}

local starterLayout: { StarterSegment } = {
	{ kind = "TrapRoom", mobs = {} },
	{ kind = "Crypt", mobs = { "Skeleton", "Skeleton" } },
	{ kind = "TreasureRoom", mobs = { "BoneLord" } },
}

return deepFreeze({
	rooms = rooms,
	mobs = mobs,
	starterLayout = starterLayout,
	party = {
		powerSpreadMin = 0.8,
		powerSpreadMax = 1.2,
		hpPerPower = 1,
		lootPerPower = 0.5,
	},
	economy = {
		startingBronze = 100,
		lossPayoutFraction = 0.3,
	},
})