--!strict
-- The last few raids, newest first, so nothing is missed while the doors are open.
-- Tapping a line opens that raid's full report.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local RaidReportView = require(script.Parent:WaitForChild("RaidReportView"))

local FEED_LENGTH = 4

export type Entry = {
	report: Types.RaidReport,
	events: { Types.RaidEvent },
}

local entries: { Entry } = {}
local lines: { TextButton } = {}

-- The lines are made once and reused, so the feed never flashes as it fills
local function create(parent: Instance, onOpen: (Entry) -> ()): Frame
	local feed = Ui.group(parent, 6)
	for i = 1, FEED_LENGTH do
		local line = Ui.secondaryButton(feed, "", function()
			local entry = entries[i]
			if entry then
				onOpen(entry)
			end
		end)
		line.Visible = false
		lines[i] = line
	end
	return feed
end

local function add(report: Types.RaidReport, events: { Types.RaidEvent })
	table.insert(entries, 1, { report = report, events = events })
	if #entries > FEED_LENGTH then
		table.remove(entries)
	end
	for i, line in lines do
		local entry = entries[i]
		line.Visible = entry ~= nil
		if entry then
			line.Text = RaidReportView.summary(entry.report)
		end
	end
end

return {
	create = create,
	add = add,
}
