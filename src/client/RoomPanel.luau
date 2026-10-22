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

local BuyMob = Remotes:WaitForChild("BuyMob") :: RemoteEvent

type Treasure = {
	label: TextLabel,
	bar: Frame,
	spoils: TextLabel,
}

type Row = {
	title: TextLabel,
	bar: Frame,
	status: TextLabel, -- rooms are fixed in the world; the panel only says how they're doing
	treasure: Treasure?, -- the room that holds the treasure and spoils
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

local function onHireClicked(slot: number, kind: Types.MobKind)
	local state = latest
	if state and Rules.canBuyMob(state, slot, kind) then
		BuyMob:FireServer(slot, kind)
	end
end

local function makeTreasure(frame: Frame): Treasure
	return {
		label = Ui.text(frame, "", Ui.STYLES.money),
		bar = Ui.bar(frame, 1, Ui.THEME.bronze),
		spoils = Ui.text(frame, "", Ui.STYLES.body),
	}
end

local function makeRow(container: Frame, slot: number, kind: Types.RoomKind): Row
	local stats = Catalog.rooms[kind]
	local frame = Ui.group(container, 6)
	local row: Row = {
		title = Ui.text(frame, "", Ui.STYLES.label),
		bar = Ui.bar(frame, 1, Ui.THEME.mutedText),
		status = Ui.text(frame, "", Ui.STYLES.muted),
		treasure = nil,
		hires = {},
	}
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

local function statusText(segment: Types.Segment): string
	return if segment.condition >= 100 then "Spotless" else `{segment.condition}% · fix it in the room`
end

local function updateTreasure(treasure: Treasure, state: Types.PlayerState)
	local max = Catalog.economy.treasureMax
	local empty = Rules.chestEmpty(state)
	treasure.label.Text = if empty then "Empty chest: only rookies come" else `Treasure {state.treasure}/{max}`
	treasure.label.TextColor3 = if empty then Ui.THEME.needsFix else Ui.THEME.bronze
	Ui.setBar(treasure.bar, state.treasure / max, Ui.THEME.bronze)
	treasure.spoils.Text = if state.spoils > 0 then `Spoils: {state.spoils} (stock them at the vault, or sell at the hub desk)` else "Spoils: 0"
end

local function updateRow(row: Row, state: Types.PlayerState, slot: number)
	local segment = state.dungeon.segments[slot]
	row.title.Text = roomTitle(segment, slot)
	local worn = segment.condition < 100
	Ui.setBar(row.bar, segment.condition / 100, if worn then Ui.THEME.needsFix else Ui.THEME.mutedText)
	row.status.Text = statusText(segment)
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
