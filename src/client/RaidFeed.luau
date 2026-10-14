--!strict
-- The latest raid, replaced by the next one. One line, so it never reads as a queue
-- of unread notices. Tapping it opens that raid's full report.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local RaidReportView = require(script.Parent:WaitForChild("RaidReportView"))

export type Entry = {
	report: Types.RaidReport,
	events: { Types.RaidEvent },
}

local latest: Entry? = nil
local line: TextButton? = nil

local function create(parent: Instance, onOpen: (Entry) -> ()): Frame
	local feed = Ui.group(parent, 0)
	local button = Ui.secondaryButton(feed, "", function()
		if latest then
			onOpen(latest)
		end
	end)
	button.TextWrapped = true -- a reason can run to a second line
	button.Visible = false
	line = button
	return feed
end

local function add(report: Types.RaidReport, events: { Types.RaidEvent })
	latest = { report = report, events = events }
	local button = line
	if button then
		button.Text = RaidReportView.summary(report)
		button.Visible = true
	end
end

return {
	create = create,
	add = add,
}
