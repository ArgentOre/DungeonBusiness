--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Rules = require(Shared.Rules)

-- Apply an already-checked restock (see Rules.canRestock)
local function apply(state: Types.PlayerState, amount: number): Types.PlayerState
	return {
		bronze = state.bronze - Rules.restockCost(amount),
		treasure = state.treasure + amount,
		dungeon = state.dungeon,
	}
end

return {
	apply = apply,
}
