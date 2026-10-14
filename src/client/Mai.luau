--!strict
-- Mai, the front desk: a slime who says one line at a time. Lines decide what she says;
-- this module only shows it. A placeholder made of GUI shapes until her art lands.
local Lines = require(script.Parent:WaitForChild("Lines"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local LINE_SECONDS = 6 -- long enough to read twice, short enough not to pile up
local BUBBLE_WIDTH = 300

-- One slime hue, shifted by mood; never pink, bronze, amber or a rank colour (HUD brief)
local MOOD_COLORS = table.freeze({
	Relaxed = Color3.fromHex("BFE6DF"),
	Alert = Color3.fromHex("7FD8CF"),
	Worried = Color3.fromHex("C3CCCF"),
	Pleased = Color3.fromHex("9EF0D2"),
	Sheepish = Color3.fromHex("D3D0E6"),
} :: { [Lines.Mood]: Color3 })

local FACES = table.freeze({
	Relaxed = "-  -\nu",
	Alert = "o  o\n-",
	Worried = "o  o\n~",
	Pleased = "^  ^\nu",
	Sheepish = ">  <\n-",
} :: { [Lines.Mood]: string })

local FIRST_MOOD: Lines.Mood = "Relaxed"

export type Parts = { blob: Frame, face: TextLabel, bubble: TextButton }

local parts: Parts? = nil
local saying = 0 -- which line is current, so an older line's timer can't hide a newer one

local function makeBlob(parent: Instance): (Frame, TextLabel)
	local blob = Instance.new("Frame")
	blob.Size = UDim2.fromOffset(64, 56)
	blob.BackgroundColor3 = MOOD_COLORS[FIRST_MOOD]
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 26)
	corner.Parent = blob
	local face = Instance.new("TextLabel")
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundTransparency = 1
	face.Text = FACES[FIRST_MOOD]
	face.TextColor3 = Ui.THEME.onAccent
	face.FontFace = Ui.THEME.headingFont
	face.TextSize = 18
	face.Parent = blob
	blob.Parent = parent
	return blob, face
end

local function makeBubble(parent: Instance, onTap: () -> ()): TextButton
	local bubble = Instance.new("TextButton")
	bubble.Size = UDim2.fromOffset(BUBBLE_WIDTH, 0)
	bubble.AutomaticSize = Enum.AutomaticSize.Y
	bubble.BackgroundColor3 = Ui.THEME.text
	bubble.TextColor3 = Ui.THEME.onAccent
	bubble.FontFace = Ui.THEME.boldFont
	bubble.TextSize = 16
	bubble.TextWrapped = true
	bubble.TextXAlignment = Enum.TextXAlignment.Left
	bubble.AutoButtonColor = false
	bubble.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = bubble
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = bubble
	bubble.Activated:Connect(function()
		onTap()
	end)
	bubble.Parent = parent
	return bubble
end

-- Builds Mai once, in a row: the slime, then her bubble. `onTap` runs when the bubble is tapped
local function create(parent: Instance, onTap: () -> ()): Parts
	local row = Ui.group(parent, 10)
	local layout = row:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	local blob, face = makeBlob(row)
	local made = { blob = blob, face = face, bubble = makeBubble(row, onTap) }
	parts = made
	return made
end

-- Shows a line. It goes after a few seconds, unless `lasting` (a state, like closed doors)
local function say(line: Lines.Line, lasting: boolean?)
	local shown = parts
	if not shown then
		return
	end
	saying += 1
	local mine = saying
	shown.blob.BackgroundColor3 = MOOD_COLORS[line.mood]
	shown.face.Text = FACES[line.mood]
	shown.bubble.Text = line.text
	shown.bubble.Visible = true
	if not lasting then
		task.delay(LINE_SECONDS, function()
			if saying == mine then
				shown.bubble.Visible = false
			end
		end)
	end
end

return {
	create = create,
	say = say,
}
