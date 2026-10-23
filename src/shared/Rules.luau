--!strict
local Types = require(script.Parent.Types)
local Catalog = require(script.Parent.Catalog)

local function repairCost(segment: Types.Segment, points: number): number
	return points * Catalog.rooms[segment.kind].repairCostPerPoint
end

local function canRepair(state: Types.PlayerState, slot: number, points: number): (boolean, string?)
	local segment = state.dungeon.segments[slot]
	if not segment then
		return false, "No room in that slot"
	end
	if points <= 0 or points ~= math.floor(points) then
		return false, "Repair amount must be a whole number above zero"
	end
	if segment.condition + points > 100 then
		return false, "That's more repair than the room needs"
	end
	if repairCost(segment, points) > state.bronze then
		return false, "Not enough bronze"
	end
	return true, nil
end

local function affordableRepair(state: Types.PlayerState, slot: number): number
	local segment = state.dungeon.segments[slot]
	if not segment then
		return 0
	end
	return math.min(100 - segment.condition, state.bronze // repairCost(segment, 1))
end

-- A worn room the player can't afford a single point of: the fix prompt is refused, and
-- the player hears why instead of nothing happening
local function fixRefusal(state: Types.PlayerState, slot: number): Types.Refusal?
	local segment = state.dungeon.segments[slot]
	if segment and segment.condition < 100 and affordableRepair(state, slot) == 0 then
		return "NoBronze"
	end
	return nil
end

local function hasFreeSlot(segment: Types.Segment): boolean
	return #segment.mobs < Catalog.rooms[segment.kind].mobSlots
end

local function canBuyMob(state: Types.PlayerState, slot: number, kind: Types.MobKind): (boolean, string?)
	local segment = state.dungeon.segments[slot]
	if not segment then
		return false, "No room in that slot"
	end
	if not hasFreeSlot(segment) then
		return false, "That room has no free slot"
	end
	local hireCost = Catalog.mobs[kind].hireCost
	if hireCost == nil then
		return false, "That monster can't be hired"
	end
	if hireCost > state.bronze then
		return false, "Not enough bronze"
	end
	return true, nil
end

-- Parties still come to an empty chest, but only rookies
local function chestEmpty(state: Types.PlayerState): boolean
	return state.treasure <= 0
end

-- How strongly the treasure draws visitors, 0 (an empty chest) to 1 (a full treasure room).
-- More treasure brings stronger parties carrying better gear.
local function lure(state: Types.PlayerState): number
	return math.clamp(state.treasure / Catalog.economy.treasureMax, 0, 1)
end

-- When the next party may come in, given when the last one did (nil: none yet).
-- The server enforces it; the client counts down to it, so both read the same rule
local function nextPartyAt(lastPartyAt: number?, now: number): number
	if lastPartyAt == nil then
		return now
	end
	return math.max(now, lastPartyAt + Catalog.economy.raidIntervalSeconds)
end

local function rankOf(power: number): Types.Rank
	local found = Catalog.party.ranks[1]
	for _, rank in Catalog.party.ranks do
		if power >= rank.minPower then
			found = rank
		end
	end
	return found
end

-- Which party this is, read from its strength like its rank: the same strength is always the
-- same party, and nothing random is drawn, so raids play exactly as before
local function partyName(power: number): string
	local parties = rankOf(power).parties
	return parties[math.floor(power) % #parties + 1]
end

-- Compared as ranks, never powers: an exact comparison would tell who wins before the raid is told
local function verdict(partyPower: number, holds: number): Types.Verdict
	local party, dungeon = rankOf(partyPower).minPower, rankOf(holds).minPower
	if party < dungeon then
		return "Safe"
	elseif party == dungeon then
		return "Close"
	end
	return "Danger"
end

-- Worn rooms come first: they're the cause the administrator can fix. A win against a
-- famous party has no cause: fame only explains why a party got away
local function raidCause(report: Types.RaidReport): Types.RaidCause?
	if report.fixingWouldHaveHeld then
		return "WornRooms"
	end
	if report.rookies then
		return "Rookies"
	end
	if report.won then
		return nil
	elseif report.reputation > 0 then
		return "Fame"
	end
	return "TooTough"
end

local function isWholeAmount(amount: number): boolean
	return amount > 0 and amount == math.floor(amount)
end

local function canSell(state: Types.PlayerState, amount: number): (boolean, string?)
	if not isWholeAmount(amount) then
		return false, "Amount must be a whole number above zero"
	end
	if amount > state.spoils then
		return false, "Not that many spoils"
	end
	return true, nil
end

local function stockable(state: Types.PlayerState): number
	return math.min(state.spoils, Catalog.economy.treasureMax - state.treasure)
end

-- Why the vault turns the player away, or nil when there's something to put in it
local function stockRefusal(state: Types.PlayerState): Types.Refusal?
	if state.spoils <= 0 then
		return "NoSpoils"
	elseif state.treasure >= Catalog.economy.treasureMax then
		return "VaultFull"
	end
	return nil
end

-- How far up the vault's coin pile stands, 0 (sunk out of sight) to 1 (its full height).
-- A cube root, because a pile's volume grows with the cube of its height: this way the
-- coins you see grow in step with the treasure, and a little treasure still shows
local function pileRise(treasure: number): number
	local fill = math.clamp(treasure / Catalog.economy.treasureMax, 0, 1)
	return fill ^ (1 / 3)
end

local function canStock(state: Types.PlayerState, amount: number): (boolean, string?)
	if not isWholeAmount(amount) then
		return false, "Amount must be a whole number above zero"
	end
	if amount > state.spoils then
		return false, "Not that many spoils"
	end
	if state.treasure + amount > Catalog.economy.treasureMax then
		return false, "That's more treasure than the room holds"
	end
	return true, nil
end

return {
	chestEmpty = chestEmpty,
	nextPartyAt = nextPartyAt,
	rankOf = rankOf,
	partyName = partyName,
	verdict = verdict,
	raidCause = raidCause,
	lure = lure,
	canSell = canSell,
	stockable = stockable,
	canStock = canStock,
	stockRefusal = stockRefusal,
	pileRise = pileRise,
	repairCost = repairCost,
	canRepair = canRepair,
	affordableRepair = affordableRepair,
	fixRefusal = fixRefusal,
	hasFreeSlot = hasFreeSlot,
	canBuyMob = canBuyMob,
}
