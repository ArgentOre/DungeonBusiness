--!strict
local Types = require(script.Parent.Types)


local function deepFreeze<T>(value: T): T
	for _, child in value :: any do
		if type(child) == "table" then
			deepFreeze(child)
		end
	end
	table.freeze(value :: any)
	return value
end

local rooms: { [Types.RoomKind]: Types.RoomStats } = {
	TrapRoom = { displayName = "Trap Room", trapDamage = 10, mobSlots = 0, wearPerRaid = 13, repairCostPerPoint = 1, repairInWorld = true },
	Crypt = { displayName = "Crypt", trapDamage = 0, mobSlots = 3, wearPerRaid = 5, repairCostPerPoint = 1, repairInWorld = false },
	TreasureRoom = { displayName = "Treasure Room", trapDamage = 0, mobSlots = 1, wearPerRaid = 3, repairCostPerPoint = 2, repairInWorld = false },
}

local mobs: { [Types.MobKind]: Types.MobStats } = {
	Skeleton = { displayName = "Skeleton", maxHp = 20, damage = 4, wage = 2, hireCost = 15 },
	Slime = { displayName = "Slime", maxHp = 30, damage = 2, wage = 1, hireCost = 10 },
	BoneLord = { displayName = "Sir Rattleford", maxHp = 120, damage = 10, wage = 8, hireCost = nil },
}

local starterLayout: { Types.StarterSegment } = {
	{ kind = "TrapRoom", mobs = {} },
	{ kind = "Crypt", mobs = { "Skeleton", "Skeleton" } },
	{ kind = "TreasureRoom", mobs = { "BoneLord" } },
}

return deepFreeze({
	rooms = rooms,
	mobs = mobs,
	starterLayout = starterLayout,
	party = {
		powerSpreadMin = 0.6,
		powerSpreadMax = 1.4,
		hpPerPower = 1,
		lootPerPower = 1.25,
		mobHpWeight = 0.1,
	},
	economy = {
		startingBronze = 100,
		lossPayoutFraction = 0.3,
		raidCooldownSeconds = 2,
	},
})