--!strict
-- The front desk in the hub: every Desk gets the prompt that opens the administrator's terminal.
-- The terminal itself is the client's; the server puts the prompt in the world so it streams
-- in with the desk, and every player sees the same one.
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Catalog)

local HOLD_SECONDS = 0.3

local function addPrompt(desk: Model)
	local top = desk:FindFirstChild("DeskTop")
	if not (top and top:IsA("BasePart")) then
		warn(`A Desk in the hub has no DeskTop part, so the terminal can't be opened there`)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Catalog.terminal.promptName
	prompt.ActionText = "Open the ledger"
	prompt.ObjectText = "Front desk"
	prompt.HoldDuration = HOLD_SECONDS
	prompt.Parent = top
end

local function addTerminalPrompts(hub: Instance)
	local anyDesk = false
	for _, desk in hub:GetDescendants() do
		if desk.Name == "Desk" and desk:IsA("Model") then
			anyDesk = true
			addPrompt(desk)
		end
	end
	if not anyDesk then
		warn("No Desk in the hub, so the terminal can't be opened")
	end
end

return {
	addTerminalPrompts = addTerminalPrompts,
}
