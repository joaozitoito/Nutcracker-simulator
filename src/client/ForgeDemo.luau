-- Dev-only showcase of the image-based Ui pieces (Ui.imageButton, Ui.coin). Not part of the game HUD.
-- Studio only. Show it with the Workspace attribute "ForgeDemo" = true (server or client command bar), hide with false.
-- Its ScreenGui "ForgeDemo" also takes the attribute `PreviewSize` (Vector2) to render as if the screen had that size.
local Players = game:GetService("Players")
local Ui = require(script.Parent.Ui)

local ForgeDemo = {}
local C = Ui.Color

function ForgeDemo.start()
	local gui = Ui.make("ScreenGui", { Name = "ForgeDemo", DisplayOrder = 60, ResetOnSpawn = false, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	local area = Ui.make("Frame", { Name = "Area", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })
	local panel, face, close = Ui.panel({ title = "IMAGE PIECES DEMO", color = C.orange }, { Name = "Panel", Visible = true, Parent = area })
	local scale = Ui.make("UIScale", { Parent = panel })

	-- coin at three sizes next to live text
	for i, size in { 28, 44, 64 } do
		local x = 18 + (i - 1) * 132
		Ui.coin(size, { Name = "Coin" .. size, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(x, 106), Parent = face })
		Ui.text({ Text = ({ "250", "1.2k", "8k" })[i], TextSize = 14 + size * 0.3, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(70, 40), Position = UDim2.fromOffset(x + size * 0.8 + 8, 86), Parent = face })
	end

	-- the same button art at three sizes
	Ui.imageButton({ text = "OK", textSize = 20 }, { Name = "Small", Position = UDim2.fromOffset(18, 150), Size = UDim2.fromOffset(110, 44), Parent = face })
	Ui.imageButton({ text = "OPEN EGG", textSize = 22 }, { Name = "Wide", Position = UDim2.fromOffset(140, 150), Size = UDim2.fromOffset(262, 44), Parent = face })

	-- pressing this one edits its own text and size: text is native, the 9-slice follows the new size
	local presses = 0
	local big, bigLabel = Ui.imageButton({ text = "BUY", textSize = 34 }, { Name = "Big", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 210), Size = UDim2.fromOffset(300, 84), Parent = face })
	Ui.coin(46, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 22, 0.45, 0), ZIndex = 3, Parent = big })
	big.Activated:Connect(function()
		presses += 1
		bigLabel.Text = `BOUGHT x{presses}`
		big.Size = presses % 2 == 1 and UDim2.fromOffset(380, 66) or UDim2.fromOffset(300, 84)
	end)
	Ui.label({ Text = "Press the big button: text and size change live", TextSize = 14, TextColor3 = C.grey, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 306), Parent = face })

	local function layout()
		local preview = gui:GetAttribute("PreviewSize")
		local size = preview or gui.AbsoluteSize
		area.Size = preview and UDim2.fromOffset(preview.X, preview.Y) or UDim2.fromScale(1, 1)
		area.BackgroundTransparency = preview and 0.6 or 1
		scale.Scale = math.clamp(math.min(size.X / 440, size.Y / 400), 0.5, 1.5)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	gui:GetAttributeChangedSignal("PreviewSize"):Connect(layout)

	local function toggle()
		gui.Enabled = workspace:GetAttribute("ForgeDemo") == true
	end
	workspace:GetAttributeChangedSignal("ForgeDemo"):Connect(toggle)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	layout()
	toggle()
end

return ForgeDemo
