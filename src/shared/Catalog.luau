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
	TrapRoom = { displayName = "Trap Room", trapDamage = 10, mobSlots = 0, wearPerRaid = 13, repairCostPerPoint = 1, repairInWorld = true, holdsTreasure = false },
	Crypt = { displayName = "Crypt", trapDamage = 0, mobSlots = 3, wearPerRaid = 5, repairCostPerPoint = 1, repairInWorld = false, holdsTreasure = false },
	TreasureRoom = { displayName = "Treasure Room", trapDamage = 0, mobSlots = 1, wearPerRaid = 3, repairCostPerPoint = 2, repairInWorld = false, holdsTreasure = true },
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
		-- Every party starts from the same base, so hiring makes the dungeon stronger
		-- instead of drawing stronger parties. Treasure (strength) and a little luck move it.
		basePower = 39, -- tuned with reputation 2026-10-10: a new dungeon starts comfortable; fame brings the threat
		luckMin = 0.9,
		luckMax = 1.1,
		hpPerPower = 1,
		lootPerPower = 1.75, -- tuned with EconomySim.runAll (2026-10-09)
		-- The treasure is a dial: to an empty chest, rookies come (weaker, cheap gear);
		-- a full treasure room draws full-strength parties. Living on rookies is a
		-- way back, never a strategy.
		rookieStrength = 0.3,
		-- Each raid the dungeon holds in a row draws a slightly stronger party, up to a cap.
		-- An escape resets it. Without it, a hired and tended dungeon never loses (2026-10-10).
		reputationStep = 0.05,
		reputationMax = 10,
		rookieGearValue = 0.5,
	},
	economy = {
		startingBronze = 100,
		-- Doors open: a party arrives this often (the always-open feel test)
		raidIntervalSeconds = 20,
		-- Treasure is the lure. Defeated parties drop spoils, which are sold for bronze
		-- or stocked as treasure. An escaping party steals some treasure.
		treasureMax = 100,
		treasureStart = 100,
		treasureTakenPerEscape = 20,
		bronzePerSpoil = 1,
		-- Staff patch any room below this condition for free after each raid,
		-- so a run-down dungeon can still beat rookies and a broke player can recover
		staffPatchFloor = 25,
	},
})