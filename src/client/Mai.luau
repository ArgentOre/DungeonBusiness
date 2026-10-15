--!strict
-- Mai, the front desk: a slime who says one line at a time. Lines decide what she says;
-- this module only shows it: her portrait for the line's mood, and the line in a bubble.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Lines = require(script.Parent:WaitForChild("Lines"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local LINE_SECONDS = 6 -- long enough to read twice, short enough not to pile up
local PORTRAIT_SIZE = 100
local BUBBLE_WIDTH = 375
local FIRST_MOOD: Types.Mood = "Relaxed"
local QUIET_TRANSPARENCY = 0.6 -- with nothing to say she fades back, so she isn't always watching

export type Parts = { portrait: ImageLabel, bubble: TextButton }

local parts: Parts? = nil
local saying = 0 -- which line is current, so an older line's timer can't hide a newer one

local function makePortrait(parent: Instance): ImageLabel
	local portrait = Instance.new("ImageLabel")
	portrait.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.BackgroundTransparency = 1
	portrait.Image = Catalog.mai.portraits[FIRST_MOOD]
	portrait.ImageTransparency = QUIET_TRANSPARENCY
	portrait.Parent = parent
	return portrait
end

local function makeBubble(parent: Instance, onTap: () -> ()): TextButton
	local bubble = Instance.new("TextButton")
	bubble.Size = UDim2.fromOffset(BUBBLE_WIDTH, 0)
	bubble.AutomaticSize = Enum.AutomaticSize.Y
	bubble.BackgroundColor3 = Ui.THEME.text
	bubble.TextColor3 = Ui.THEME.onAccent
	bubble.FontFace = Ui.THEME.boldFont
	bubble.TextSize = 20
	bubble.TextWrapped = true
	bubble.TextXAlignment = Enum.TextXAlignment.Left
	bubble.AutoButtonColor = false
	bubble.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = bubble
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = bubble
	bubble.Activated:Connect(function()
		onTap()
	end)
	bubble.Parent = parent
	return bubble
end

-- Builds Mai once, in a row: her portrait, then her bubble. `onTap` runs when the bubble is tapped
local function create(parent: Instance, onTap: () -> ()): Parts
	local row = Ui.group(parent, 10)
	local layout = row:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	local made = { portrait = makePortrait(row), bubble = makeBubble(row, onTap) }
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
	shown.portrait.Image = Catalog.mai.portraits[line.mood]
	shown.portrait.ImageTransparency = 0
	shown.bubble.Text = line.text
	shown.bubble.Visible = true
	if not lasting then
		task.delay(LINE_SECONDS, function()
			if saying == mine then
				shown.bubble.Visible = false
				shown.portrait.ImageTransparency = QUIET_TRANSPARENCY
			end
		end)
	end
end

return {
	create = create,
	say = say,
}
