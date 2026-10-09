--!strict
-- Spoils: what defeated adventurers leave behind, and where it goes next.
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)

-- How much a party's gear is worth, from cheap rookie gear (lure 0) to full value (lure 1)
local function gearValue(lure: number): number
	local rookie = Catalog.party.rookieGearValue
	return rookie + (1 - rookie) * lure
end

-- A defeated party drops its possessions; a party that escapes takes them along
local function dropped(result: Types.RaidResult, lure: number): number
	return if result.won then math.round(result.loot * gearValue(lure)) else 0
end

-- Apply an already-checked sale (see Rules.canSell)
local function sell(state: Types.PlayerState, amount: number): Types.PlayerState
	return {
		bronze = state.bronze + amount * Catalog.economy.bronzePerSpoil,
		treasure = state.treasure,
		spoils = state.spoils - amount,
		dungeon = state.dungeon,
	}
end

-- Apply an already-checked stocking (see Rules.canStock)
local function stock(state: Types.PlayerState, amount: number): Types.PlayerState
	return {
		bronze = state.bronze,
		treasure = state.treasure + amount,
		spoils = state.spoils - amount,
		dungeon = state.dungeon,
	}
end

return {
	dropped = dropped,
	sell = sell,
	stock = stock,
}
