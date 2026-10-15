--!strict
-- Top right: the dungeon's OPEN / CLOSED sign, hanging from two strings like a shop sign
-- (HUD Brief frames 1 and 4). Open, it's lit pink; closed, an outline. A small caption
-- under it says what a tap does.
local Ui = require(script.Parent:WaitForChild("Ui"))

local WIDTH, HEIGHT = 160, 58
local LIP = 5 -- the darker strip under a lit sign, so it reads as a board, not a flat button
local STRING_LENGTH, STRING_GAP = 22, 100
local STRING_COLOR = Color3.fromHex("6A6272")
local LIP_COLOR = Color3.fromHex("C96A93")

export type Parts = { sign: TextButton, board: Frame, caption: TextLabel }

local function show(parts: Parts, open: boolean)
	parts.sign.Text = if open then "OPEN" else "CLOSED"
	parts.sign.BackgroundColor3 = if open then Ui.THEME.accent else Ui.THEME.panel
	parts.sign.TextColor3 = if open then Ui.THEME.onAccent else Ui.THEME.accent
	parts.board.BackgroundTransparency = if open then 0 else 1
	parts.caption.Text = if open then "tap to close" else "tap to open"
end

local function hangingString(parent: Instance, x: number)
	local cord = Instance.new("Frame")
	cord.Size = UDim2.fromOffset(2, STRING_LENGTH)
	cord.Position = UDim2.new(0.5, x - 1, 0, 0)
	cord.BackgroundColor3 = STRING_COLOR
	cord.BorderSizePixel = 0
	cord.Parent = parent
end

-- The board: a frame in the lip colour with the button on top, `LIP` short of its bottom
local function makeBoard(parent: Instance): Frame
	local board = Instance.new("Frame")
	board.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	board.Position = UDim2.new(0.5, -WIDTH / 2, 0, STRING_LENGTH)
	board.BackgroundColor3 = LIP_COLOR
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = board
	board.Parent = parent
	return board
end

-- `onToggle` gets the new state each time the sign is tapped
local function create(parent: Instance, onToggle: (open: boolean) -> ()): Parts
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromOffset(WIDTH, STRING_LENGTH + HEIGHT + 24)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	hangingString(holder, -STRING_GAP / 2)
	hangingString(holder, STRING_GAP / 2)
	local board = makeBoard(holder)

	local open = false
	local parts: Parts
	local sign = Ui.primaryButton(board, "", function()
		open = not open
		show(parts, open)
		onToggle(open)
	end)
	sign.Size = UDim2.new(1, 0, 1, -LIP)
	sign.TextSize = 28
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Ui.THEME.accent
	stroke.Thickness = 3
	stroke.Parent = sign

	local caption = Ui.text(holder, "", Ui.STYLES.muted)
	caption.Position = UDim2.fromOffset(0, STRING_LENGTH + HEIGHT + 4)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.TextSize = 14

	parts = { sign = sign, board = board, caption = caption }
	show(parts, open)
	return parts
end

return {
	create = create,
}
