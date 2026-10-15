--!strict
-- Top right: the dungeon's OPEN / CLOSED sign, the one main action on the HUD. Closed, it's
-- filled pink, since opening is what a new administrator should do; open, it steps back.
local Ui = require(script.Parent:WaitForChild("Ui"))

local WIDTH = 200

export type Parts = { sign: TextButton }

local function show(sign: TextButton, open: boolean)
	sign.Text = if open then "OPEN\ntap to close" else "CLOSED\ntap to open"
	sign.BackgroundColor3 = if open then Ui.THEME.panel else Ui.THEME.accent
	sign.TextColor3 = if open then Ui.THEME.accent else Ui.THEME.onAccent
end

-- `onToggle` gets the new state each time the sign is tapped
local function create(parent: Instance, onToggle: (open: boolean) -> ()): Parts
	local open = false
	local sign: TextButton
	sign = Ui.primaryButton(parent, "", function()
		open = not open
		show(sign, open)
		onToggle(open)
	end)
	sign.Size = UDim2.fromOffset(WIDTH, 64)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Ui.THEME.accent
	stroke.Thickness = 2
	stroke.Parent = sign
	show(sign, open)
	return { sign = sign }
end

return {
	create = create,
}
