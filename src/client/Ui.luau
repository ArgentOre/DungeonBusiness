--!strict
-- Styled GUI building blocks. The style is the Design Doc's (r7): a charcoal ground,
-- pink only on things the player can act on, bronze-gold only for money.

local THEME = table.freeze({
	panel = Color3.fromHex("221F26"),
	panelBorder = Color3.fromHex("38333F"),
	text = Color3.fromHex("EDE9F0"),
	mutedText = Color3.fromHex("B3ABBD"),
	accent = Color3.fromHex("F28DB8"),
	onAccent = Color3.fromHex("1A1418"),
	bronze = Color3.fromHex("D9A55B"),
	needsFix = Color3.fromHex("E8A657"),
	headingFont = Font.fromEnum(Enum.Font.FredokaOne),
	bodyFont = Font.new("rbxasset://fonts/families/Nunito.json"),
	boldFont = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold),
})

export type TextStyle = { font: Font, size: number, color: Color3 }

local STYLES = table.freeze({
	heading = table.freeze({ font = THEME.headingFont, size = 26, color = THEME.text }) :: TextStyle,
	body = table.freeze({ font = THEME.bodyFont, size = 16, color = THEME.text }) :: TextStyle,
	label = table.freeze({ font = THEME.boldFont, size = 16, color = THEME.text }) :: TextStyle,
	muted = table.freeze({ font = THEME.bodyFont, size = 14, color = THEME.mutedText }) :: TextStyle,
	money = table.freeze({ font = THEME.boldFont, size = 18, color = THEME.bronze }) :: TextStyle,
	warning = table.freeze({ font = THEME.boldFont, size = 14, color = THEME.needsFix }) :: TextStyle,
})

local BUTTON_HEIGHT = 44 -- comfortable touch target on phones
local PRIMARY_HEIGHT = 52

local function nextOrder(parent: Instance): number
	return #parent:GetChildren()
end

local function addCorner(gui: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = gui
end

local function addStroke(gui: GuiObject, color: Color3)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Parent = gui
end

local function addPadding(gui: GuiObject, pixels: number)
	local padding = Instance.new("UIPadding")
	local inset = UDim.new(0, pixels)
	padding.PaddingTop = inset
	padding.PaddingBottom = inset
	padding.PaddingLeft = inset
	padding.PaddingRight = inset
	padding.Parent = gui
end

local function addList(gui: GuiObject, gap: number)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
end

-- A rounded card that grows to fit its contents, stacked top to bottom
local function panel(parent: Instance, width: number, gap: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(width, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = THEME.panel
	frame.LayoutOrder = nextOrder(parent)
	addCorner(frame, 16)
	addStroke(frame, THEME.panelBorder)
	addPadding(frame, 14)
	addList(frame, gap)
	frame.Parent = parent
	return frame
end

-- An invisible full-width box that stacks its contents; for grouping rows inside a panel
local function group(parent: Instance, gap: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = nextOrder(parent)
	addList(frame, gap)
	frame.Parent = parent
	return frame
end

local function text(parent: Instance, content: string, style: TextStyle): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.FontFace = style.font
	label.TextSize = style.size
	label.TextColor3 = style.color
	label.Text = content
	label.LayoutOrder = nextOrder(parent)
	label.Parent = parent
	return label
end

-- A thin track filled to `fraction` (0–1); shows a room's condition
local function bar(parent: Instance, fraction: number, color: Color3): Frame
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 8)
	track.BackgroundColor3 = THEME.panelBorder
	track.LayoutOrder = nextOrder(parent)
	addCorner(track, 4)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	fill.BackgroundColor3 = color
	addCorner(fill, 4)
	fill.Parent = track
	track.Parent = parent
	return track
end

local function button(parent: Instance, content: string, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	btn.FontFace = THEME.boldFont
	btn.TextSize = 16
	btn.Text = content
	btn.LayoutOrder = nextOrder(parent)
	addCorner(btn, 12)
	btn.Activated:Connect(function()
		onClick()
	end)
	btn.Parent = parent
	return btn
end

-- The one main action on a screen: filled pink
local function primaryButton(parent: Instance, content: string, onClick: () -> ()): TextButton
	local btn = button(parent, content, onClick)
	btn.Size = UDim2.new(1, 0, 0, PRIMARY_HEIGHT)
	btn.BackgroundColor3 = THEME.accent
	btn.TextColor3 = THEME.onAccent
	btn.FontFace = THEME.headingFont
	btn.TextSize = 20
	return btn
end

-- Every other action: pink outline
local function secondaryButton(parent: Instance, content: string, onClick: () -> ()): TextButton
	local btn = button(parent, content, onClick)
	btn.BackgroundColor3 = THEME.panel
	btn.TextColor3 = THEME.accent
	addStroke(btn, THEME.accent)
	return btn
end

-- Not pink, because it can't be used right now
local function disable(btn: TextButton)
	btn.AutoButtonColor = false
	btn.TextColor3 = THEME.mutedText
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = THEME.panelBorder
	end
end

-- Removes rows but keeps the panel's own layout, padding and styling
local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return {
	THEME = THEME,
	STYLES = STYLES,
	panel = panel,
	group = group,
	text = text,
	bar = bar,
	primaryButton = primaryButton,
	secondaryButton = secondaryButton,
	disable = disable,
	clear = clear,
}
