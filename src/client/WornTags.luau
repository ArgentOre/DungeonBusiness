--!strict
-- Bottom right: one amber tag per worn room, with what fixing it costs. A tag shows while
-- its room is worn and goes when it's fixed. Mess says where; the tag says how much.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Rules = require(Shared:WaitForChild("Rules"))
local Ui = require(script.Parent:WaitForChild("Ui"))

-- What a worn room's tag says, or nil for a room that needs nothing
local function tagText(segment: Types.Segment): string?
	if segment.condition >= 100 then
		return nil
	end
	local cost = Rules.repairCost(segment, 100 - segment.condition)
	return `{Catalog.rooms[segment.kind].displayName} needs fixing · {cost} bronze`
end

local tags: { [number]: TextLabel } = {} -- one per slot, made the first time that room wears

local function tagFor(container: Frame, slot: number): TextLabel
	local existing = tags[slot]
	if existing then
		return existing
	end
	local tag = Ui.text(container, "", Ui.STYLES.warning)
	tag.TextXAlignment = Enum.TextXAlignment.Right
	tag.LayoutOrder = slot
	tags[slot] = tag
	return tag
end

-- Updates the tags in place: a flash-free show/hide rather than a rebuild
local function render(container: Frame, state: Types.PlayerState)
	for slot, segment in state.dungeon.segments do
		local text = tagText(segment)
		if text then
			local tag = tagFor(container, slot)
			tag.Text = text
			tag.Visible = true
		elseif tags[slot] then
			tags[slot].Visible = false
		end
	end
	for slot, tag in tags do
		if not state.dungeon.segments[slot] then
			tag.Visible = false
		end
	end
end

return {
	tagText = tagText,
	render = render,
}
