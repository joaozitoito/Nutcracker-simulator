-- Hammer evolution on the HUD: a small "HAMMER: <name>" pill under the stats, and an unlock banner with the new model.
-- Reads only the server's "HammerTier" attribute; sends nothing. The hammer model itself is handled by Effects.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local HammerModel = require(Shared.HammerModel)
local Hammers = require(Shared.Hammers)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)

local HammerUi = {}

local player = Players.LocalPlayer
local C = Ui.Color

local function tierOf(): number
	return math.clamp(player:GetAttribute("HammerTier") or 1, 1, #Hammers.Tiers)
end

-- Unlock banner. Waits for an egg reveal or another banner so they never stack on top of each other.
local function celebrate(index: number)
	local root = Hud.root
	local tier = Hammers.Tiers[index]
	task.spawn(function()
		while root:FindFirstChild("EggOpening") or root:FindFirstChild("CollectionReward") or root:FindFirstChild("HammerUnlock") do
			task.wait(0.2)
		end
		local banner, face = Ui.card({ color = C.night, radius = 20, depth = 6 }, {
			Name = "HammerUnlock",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(380, 112),
			ZIndex = 25,
			Parent = root,
		})
		local stage, stageFace = Ui.card({ color = tier.color:Lerp(C.white, 0.35), radius = 16, depth = 4 }, { Size = UDim2.fromOffset(96, 96), Position = UDim2.fromOffset(8, 4), Parent = face })
		local view = Ui.viewport(HammerModel.build(index), { Size = UDim2.fromScale(1, 1), Parent = stageFace })
		Ui.text({ Text = "NEW HAMMER!", TextSize = 26, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(260, 32), Position = UDim2.fromOffset(114, 10), Parent = face })
		Ui.text({ Text = tier.name, TextSize = 24, TextColor3 = tier.color:Lerp(C.white, 0.3), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(260, 30), Position = UDim2.fromOffset(114, 42), Parent = face })
		Ui.text({ Text = `Tier {index} of {#Hammers.Tiers}`, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(260, 18), Position = UDim2.fromOffset(114, 74), Parent = face })
		Ui.pop(banner, true)
		Ui.bump(stage, 1.3)
		Effects.play("buy")
		-- slow turn so the new silhouette reads
		local camera = view.CurrentCamera
		local centre = view:FindFirstChildWhichIsA("Model"):GetBoundingBox().Position
		local offset = camera.CFrame.Position - centre
		local started = os.clock()
		while os.clock() - started < 3.5 and banner.Parent do
			local spin = CFrame.Angles(0, (os.clock() - started) * 1.4, 0)
			camera.CFrame = CFrame.lookAt(centre + spin * offset, centre)
			task.wait()
		end
		Ui.pop(banner, false)
		task.wait(0.15)
		banner:Destroy()
	end)
end

function HammerUi.start()
	local stats = Hud.root:WaitForChild("Stats")
	local pill, face = Ui.card({ color = C.night, radius = 15, depth = 4 }, { Name = "Hammer", Size = UDim2.fromOffset(196, 30), Position = UDim2.fromOffset(12, 222), Parent = stats })
	Ui.text({ Text = "🔨", TextSize = 16, Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(4, 0), Parent = face })
	local label = Ui.text({ Name = "Name", RichText = true, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -34, 1, 0), Position = UDim2.fromOffset(30, 0), Parent = face })

	local shown = tierOf()
	local function refresh()
		local index = tierOf()
		local tier = Hammers.Tiers[index]
		label.Text = `HAMMER: <font color="#{tier.color:Lerp(C.white, 0.25):ToHex()}">{tier.name:upper()}</font>`
		if index > shown then
			Ui.bump(pill, 1.15)
			celebrate(index)
		end
		shown = index
	end
	player:GetAttributeChangedSignal("HammerTier"):Connect(refresh)
	refresh()
end

return HammerUi
