--!strict
-- The raid log, told as it happens: each raid plays out line by line, like progress
-- reports from inside the dungeon. The server already knows how the raid ended; the
-- client only tells it slowly, so nothing on the server waits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local EventText = require(Shared:WaitForChild("EventText"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local FASTEST_LINE_SECONDS = 0.2 -- still readable
local SLOWEST_LINE_SECONDS = 1 -- a short raid doesn't drag

local telling: thread? = nil -- the raid being told right now, if any
local whenTold: (() -> ())? = nil -- what happens when that telling ends

-- Spreads a raid's lines over `seconds`, within what's comfortable to read
local function secondsPerLine(lineCount: number, seconds: number): number
	return math.clamp(seconds / math.max(lineCount, 1), FASTEST_LINE_SECONDS, SLOWEST_LINE_SECONDS)
end

-- Ends the telling in progress early. Whatever was waiting for its end happens now,
-- so a raid's result is never lost because the next raid arrived first
local function stop()
	if telling and coroutine.running() ~= telling then
		task.cancel(telling)
	end
	telling = nil
	local finish = whenTold
	whenTold = nil
	if finish then
		finish()
	end
end

local function addLine(lines: Instance, event: Types.RaidEvent)
	Ui.text(lines, EventText.format(event), Ui.STYLES.muted)
end

-- The whole log at once: for a raid that has already been told
local function show(lines: Instance, events: { Types.RaidEvent })
	stop()
	Ui.clear(lines)
	for _, event in events do
		addLine(lines, event)
	end
end

-- Tells a raid one line at a time over about `seconds`, then calls `onTold`
local function narrate(lines: Instance, events: { Types.RaidEvent }, seconds: number, onTold: () -> ())
	stop()
	Ui.clear(lines)
	whenTold = onTold
	local pause = secondsPerLine(#events, seconds)
	telling = task.spawn(function()
		for i, event in events do
			if i > 1 then
				task.wait(pause)
			end
			addLine(lines, event)
		end
		stop()
	end)
end

return {
	secondsPerLine = secondsPerLine,
	show = show,
	narrate = narrate,
}
