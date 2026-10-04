--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)

local function amount(result: Types.RaidResult): number
	if result.won then
		return result.loot
	end
	return math.round(result.loot * Catalog.economy.lossPayoutFraction)
end

return {
	amount = amount,
}