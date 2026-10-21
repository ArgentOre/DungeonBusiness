--!strict
-- What Mai, the front desk, says: one short line per moment, in deadpan workplace voice.
-- Pure: the caller picks the variant, so the same moment and variant always read the same.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Rules = require(Shared:WaitForChild("Rules"))
local Catalog = require(Shared:WaitForChild("Catalog"))

export type Mood = Types.Mood
export type Line = { text: string, mood: Mood }

-- The first "%s" is the party's name, the second its rank letter
local ARRIVALS = table.freeze({
	Safe = table.freeze({
		"%s, Rank %s, at the door. We've got this.",
		"%s are here. Rank %s. Nothing we can't handle.",
		"Visitors: %s, Rank %s. I'll put the kettle on.",
	}),
	Close = table.freeze({
		"%s, Rank %s. Could go either way.",
		"%s at the door, Rank %s. Look sharp, everyone.",
		"%s, Rank %s. This one's a fair fight.",
	}),
	Danger = table.freeze({
		"%s, Rank %s. That's… above our pay grade.",
		"%s at the door, Rank %s. Too late to close?",
		"%s, Rank %s. Everyone, please act natural.",
	}),
} :: { [Types.Verdict]: { string } })

local ARRIVAL_MOODS = table.freeze({ Safe = "Relaxed", Close = "Alert", Danger = "Worried" } :: { [Types.Verdict]: Mood })

-- "%s" is the party's name
local ROOKIES_ARRIVE = table.freeze({
	"%s. Rookies. Be gentle.",
	"Rookies at the door: %s. Their map is upside down.",
	"%s, rookies. They heard the chest was empty.",
})

local HELD = table.freeze({
	"They left their boots. Nice boots.",
	"Sent home. Spoils are in.",
	"Held. The skeletons would like a raise.",
})

local HELD_ROOKIES = table.freeze({
	"Rookies sent home. Stock the chest and better parties come.",
	"Easy one. Their gear isn't worth much, though.",
	"Rookies again. An empty chest won't draw anyone better.",
})

local ESCAPES = table.freeze({
	WornRooms = table.freeze({
		"They got through a worn room. Fixed up, we'd have held.",
		"A worn room let them past. Worth fixing.",
		"They slipped by. A few repairs and they wouldn't have.",
	}),
	Rookies = table.freeze({
		"Even the rookies got out. That's a little embarrassing.",
		"Rookies, gone. Somehow.",
		"The rookies escaped. Let's not tell anyone.",
	}),
	Fame = table.freeze({
		"They got out. Word gets around, and tougher parties come.",
		"Our fame drew a tough one, and they got out.",
		"Escaped. Being famous has its downsides.",
	}),
	TooTough = table.freeze({
		"Too strong for us today. They got out.",
		"Nothing in here could have stopped that one.",
		"That party was just too tough.",
	}),
} :: { [Types.RaidCause]: { string } })

local DOORS_CLOSED = table.freeze({
	"Closed for renovations. Take your time.",
	"Doors are shut. Tea break.",
	"Closed. Nice and quiet in here.",
})

local DOORS_OPEN = table.freeze({
	"Doors open. First party's on the way.",
	"We're open for business.",
	"Open! Places, everyone.",
})

-- Stern, but it says what to do about it
local REFUSALS = table.freeze({
	NoBronze = table.freeze({
		"Not enough bronze for that. Sell some spoils first.",
		"The repair budget is empty. The hub desk buys spoils.",
		"We can't afford that. Spoils sell at the hub desk.",
	}),
} :: { [Types.Refusal]: { string } })

local LEDGER_HINTS = table.freeze({
	"The full story's in the ledger, at the front desk in the hub.",
	"Every raid's in the ledger. It's on the desk in the hub.",
	"Paperwork's at the hub desk. All of it. Every line.",
})

local function pick(list: { string }, variant: number): string
	return list[(variant - 1) % #list + 1]
end

-- As a party arrives: its rank against what the dungeon holds
local function arrival(report: Types.RaidReport, holds: number, variant: number): Line
	local name = Rules.partyName(report.partyPower)
	if report.rookies then
		return { text = string.format(pick(ROOKIES_ARRIVE, variant), name), mood = "Relaxed" }
	end
	local verdict: Types.Verdict = Rules.verdict(report.partyPower, holds)
	local letter = Rules.rankOf(report.partyPower).letter
	return { text = string.format(pick(ARRIVALS[verdict], variant), name, letter), mood = ARRIVAL_MOODS[verdict] }
end

-- Once the raid has been told: how it went, and why
local function result(report: Types.RaidReport, variant: number): Line
	local cause: Types.RaidCause? = Rules.raidCause(report)
	if report.won then
		return { text = pick(if cause == "Rookies" then HELD_ROOKIES else HELD, variant), mood = "Pleased" }
	end
	assert(cause, "Rules.raidCause names a cause for every escape")
	return { text = pick(ESCAPES[cause], variant), mood = "Sheepish" }
end

local function doors(open: boolean, variant: number): Line
	return if open
		then { text = pick(DOORS_OPEN, variant), mood = "Alert" }
		else { text = pick(DOORS_CLOSED, variant), mood = "Relaxed" }
end

-- When the server turns something down: why, and what to do instead
local function refusal(reason: Types.Refusal, variant: number): Line
	return { text = pick(REFUSALS[reason], variant), mood = "Alert" }
end

-- When she's tapped: the details aren't hers to read out, they're in the ledger
local function ledgerHint(variant: number): Line
	return { text = pick(LEDGER_HINTS, variant), mood = "Relaxed" }
end

local function longestPartyName(): string
	local longest = ""
	for _, rank in Catalog.party.ranks do
		for _, name in rank.parties do
			if #name > #longest then
				longest = name
			end
		end
	end
	return longest
end

-- Every line, filled in with the longest party name, for checking length and tone in one place
local function everyLine(): { string }
	local all: { string } = {}
	local name = longestPartyName()
	local function add(list: { string })
		for _, text in list do
			local withName = string.gsub(text, "%%s", name, 1)
			table.insert(all, (string.gsub(withName, "%%s", "C")))
		end
	end
	for _, verdict: Types.Verdict in { "Safe", "Close", "Danger" } :: { Types.Verdict } do
		add(ARRIVALS[verdict])
	end
	for _, cause: Types.RaidCause in { "WornRooms", "Rookies", "Fame", "TooTough" } :: { Types.RaidCause } do
		add(ESCAPES[cause])
	end
	for _, reason: Types.Refusal in { "NoBronze" } :: { Types.Refusal } do
		add(REFUSALS[reason])
	end
	for _, list in { ROOKIES_ARRIVE, HELD, HELD_ROOKIES, DOORS_CLOSED, DOORS_OPEN, LEDGER_HINTS } do
		add(list)
	end
	return all
end

return {
	arrival = arrival,
	result = result,
	doors = doors,
	ledgerHint = ledgerHint,
	refusal = refusal,
	everyLine = everyLine,
}
