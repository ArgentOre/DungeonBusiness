--!strict
-- The "Your dungeon" panel: one row per room, built once and then updated in place.
-- Rebuilding the rows on every change made the panel flash, because Roblox sizes
-- auto-sized text a frame late, so the panel collapsed for a frame each time.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Types = require(Shared:WaitForChild("Types"))
local Rules = require(Shared:WaitForChild("Rules"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Repair = Remotes:WaitForChild("Repair") :: RemoteEvent
local BuyMob = Remotes:WaitForChild("BuyMob") :: RemoteEvent
local Restock = Remotes:WaitForChild("Restock") :: RemoteEvent

type Row = {
	title: TextLabel,
	bar: Frame,
	status: TextLabel?, -- rooms repaired in the world
	repair: TextButton?, -- rooms repaired from the panel
	treasure: { label: TextLabel, bar: Frame, restock: TextButton }?, -- the room that holds the treasure
	hires: { [Types.MobKind]: TextButton },
}

local function hireableKinds(): { Types.MobKind }
	local kinds: { Types.MobKind } = {}
	for kind: Types.MobKind, stats in Catalog.mobs do
		if stats.hireCost then
			table.insert(kinds, kind)
		end
	end
	table.sort(kinds) -- Catalog.mobs is a dictionary, so its order isn't stable
	return kinds
end

local HIREABLE = table.freeze(hireableKinds())

local rows: { Row } = {}
local builtFor = "" -- the room kinds the rows were built for, in order
local builtIn: Frame? = nil -- the panel the rows were built in
local latest: Types.PlayerState? = nil -- what the buttons act on when clicked

local function layoutOf(state: Types.PlayerState): string
	local kinds = {}
	for _, segment in state.dungeon.segments do
		table.insert(kinds, segment.kind)
	end
	return table.concat(kinds, ",")
end

local function onRepairClicked(slot: number)
	local state = latest
	local points = if state then Rules.affordableRepair(state, slot) else 0
	if points > 0 then
		Repair:FireServer(slot, points)
	end
end

local function onHireClicked(slot: number, kind: Types.MobKind)
	local state = latest
	if state and Rules.canBuyMob(state, slot, kind) then
		BuyMob:FireServer(slot, kind)
	end
end

local function onRestockClicked()
	local state = latest
	local amount = if state then Rules.affordableRestock(state) else 0
	if amount > 0 then
		Restock:FireServer(amount)
	end
end

local function makeTreasure(frame: Frame): { label: TextLabel, bar: Frame, restock: TextButton }
	return {
		label = Ui.text(frame, "", Ui.STYLES.money),
		bar = Ui.bar(frame, 1, Ui.THEME.bronze),
		restock = Ui.secondaryButton(frame, "", onRestockClicked),
	}
end

local function makeRow(container: Frame, slot: number, kind: Types.RoomKind): Row
	local stats = Catalog.rooms[kind]
	local frame = Ui.group(container, 6)
	local row: Row = {
		title = Ui.text(frame, "", Ui.STYLES.label),
		bar = Ui.bar(frame, 1, Ui.THEME.mutedText),
		status = nil,
		repair = nil,
		treasure = nil,
		hires = {},
	}
	if stats.repairInWorld then
		row.status = Ui.text(frame, "", Ui.STYLES.muted)
	else
		row.repair = Ui.secondaryButton(frame, "", function()
			onRepairClicked(slot)
		end)
	end
	if stats.holdsTreasure then
		row.treasure = makeTreasure(frame)
	end
	if stats.mobSlots > 0 then
		for _, mobKind: Types.MobKind in HIREABLE do
			local mob = Catalog.mobs[mobKind]
			row.hires[mobKind] = Ui.secondaryButton(frame, `Hire {mob.displayName} · {mob.hireCost} bronze`, function()
				onHireClicked(slot, mobKind)
			end)
		end
	end
	return row
end

local function roomTitle(segment: Types.Segment, slot: number): string
	local stats = Catalog.rooms[segment.kind]
	local staff = if stats.mobSlots > 0 then `   staff {#segment.mobs}/{stats.mobSlots}` else ""
	return `{slot} · {stats.displayName}{staff}`
end

local function repairButtonText(segment: Types.Segment, points: number): string
	if segment.condition >= 100 then
		return "Spotless"
	end
	if points == 0 then
		return "Repair (not enough bronze)"
	end
	return `Repair +{points} · {Rules.repairCost(segment, points)} bronze`
end

local function restockButtonText(state: Types.PlayerState, amount: number): string
	if state.treasure >= Catalog.economy.treasureMax then
		return "Treasure is full"
	end
	if amount == 0 then
		return "Restock (not enough bronze)"
	end
	return `Restock +{amount} · {Rules.restockCost(amount)} bronze`
end

local function updateTreasure(treasure: { label: TextLabel, bar: Frame, restock: TextButton }, state: Types.PlayerState)
	local max = Catalog.economy.treasureMax
	local empty = state.treasure <= 0
	treasure.label.Text = if empty then "No treasure: no visitors!" else `Treasure {state.treasure}/{max}`
	treasure.label.TextColor3 = if empty then Ui.THEME.needsFix else Ui.THEME.bronze
	Ui.setBar(treasure.bar, state.treasure / max, Ui.THEME.bronze)
	local amount = Rules.affordableRestock(state)
	treasure.restock.Text = restockButtonText(state, amount)
	Ui.setEnabled(treasure.restock, amount > 0)
end

local function updateRow(row: Row, state: Types.PlayerState, slot: number)
	local segment = state.dungeon.segments[slot]
	row.title.Text = roomTitle(segment, slot)
	local worn = segment.condition < 100
	Ui.setBar(row.bar, segment.condition / 100, if worn then Ui.THEME.needsFix else Ui.THEME.mutedText)
	if row.status then
		row.status.Text = `{segment.condition}% · fix it in the room`
	end
	if row.repair then
		local points = Rules.affordableRepair(state, slot)
		row.repair.Text = repairButtonText(segment, points)
		Ui.setEnabled(row.repair, points > 0)
	end
	if row.treasure then
		updateTreasure(row.treasure, state)
	end
	local hasRoom = Rules.hasFreeSlot(segment)
	for _, kind: Types.MobKind in HIREABLE do
		local button = row.hires[kind]
		if button then
			local allowed = Rules.canBuyMob(state, slot, kind) -- also returns a reason; only the yes/no matters here
			button.Visible = hasRoom
			Ui.setEnabled(button, allowed)
		end
	end
end

local function render(container: Frame, state: Types.PlayerState)
	latest = state
	local layout = layoutOf(state)
	if layout ~= builtFor or container ~= builtIn then
		Ui.clear(container)
		rows = {}
		for slot, segment in state.dungeon.segments do
			rows[slot] = makeRow(container, slot, segment.kind)
		end
		builtFor = layout
		builtIn = container
	end
	for slot, row in rows do
		updateRow(row, state, slot)
	end
end

return {
	render = render,
}
