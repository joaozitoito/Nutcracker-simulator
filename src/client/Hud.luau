-- HUD: coins + strength (left), assigned-nut card (top), shop button + toasts (bottom), shop panel and "Oops!" popup.
-- Reads everything from replicated attributes; the only request it sends is BuyStrength.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Effects = require(script.Parent.Effects)

local Hud = {}

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(40, 30, 60)
local GREEN = Color3.fromRGB(88, 214, 60)
local RED = Color3.fromRGB(255, 70, 90)
local GOLD = Color3.fromRGB(255, 205, 50)
local ORANGE = Color3.fromRGB(255, 150, 40)
local GREY = Color3.fromRGB(150, 150, 165)

local function make(class: string, props: { [string]: any }, children: { Instance }?)
	local object = Instance.new(class)
	for key, value in props do
		object[key] = value
	end
	for _, child in children or {} do
		child.Parent = object
	end
	return object
end

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(thickness: number, color: Color3?)
	return make("UIStroke", { Thickness = thickness, Color = color or DARK, LineJoinMode = Enum.LineJoinMode.Round })
end

-- white text with a chunky dark outline (the simulator look)
local function title(props: { [string]: any })
	local label = make("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextColor3 = WHITE, TextSize = 28 }, {
		stroke(3),
	})
	for key, value in props do
		label[key] = value
	end
	return label
end

-- plain dark text for inside white panels
local function body(props: { [string]: any })
	local label = make("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextColor3 = DARK, TextSize = 20 })
	for key, value in props do
		label[key] = value
	end
	return label
end

local function panel(props: { [string]: any })
	local frame = make("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0 }, { corner(18), stroke(4) })
	for key, value in props do
		frame[key] = value
	end
	return frame
end

-- returns the button and its text label
local function button(text: string, color: Color3, props: { [string]: any })
	local label = title({ Text = text, Size = UDim2.fromScale(1, 1), TextSize = 26 })
	local object = make("TextButton", { Text = "", BackgroundColor3 = color, BorderSizePixel = 0 }, {
		corner(14),
		make("UIStroke", { Thickness = 4, Color = DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		label,
	})
	for key, value in props do
		object[key] = value
	end
	return object, label
end

local function coinIcon(size: number, position: UDim2)
	return make("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
	}, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		stroke(3, Color3.fromRGB(170, 105, 20)),
		make("Frame", {
			Size = UDim2.fromScale(0.45, 0.45),
			Position = UDim2.fromScale(0.275, 0.275),
			BackgroundColor3 = Color3.fromRGB(255, 235, 140),
			BorderSizePixel = 0,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
	})
end

local toasts

function Hud.toast(text: string, color: Color3?)
	if not toasts then
		return
	end
	local label = title({ Text = text, TextColor3 = color or WHITE, Size = UDim2.new(1, 0, 0, 34), TextSize = 26, Parent = toasts })
	task.delay(1.8, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(label.UIStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.wait(0.4)
		label:Destroy()
	end)
end

function Hud.start()
	local gui = make("ScreenGui", { Name = "NutHud", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	local scale = make("UIScale", { Parent = gui })
	local camera = workspace.CurrentCamera
	local function rescale()
		-- designed at 600px tall; phones in landscape (~375px) get 0.7, 1080p gets 1.5
		scale.Scale = math.clamp(camera.ViewportSize.Y / 600, 0.7, 1.5)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	---------------------------------------------------------------- stats (left, mid height)
	local coinsLabel = title({ Text = "0", TextSize = 38, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 46), Position = UDim2.fromOffset(56, 0) })
	local coinsPulse = make("UIScale", { Parent = coinsLabel })
	local strengthLabel = title({ Text = "1", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 40), Position = UDim2.fromOffset(56, 54) })
	make("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(260, 96),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		coinIcon(44, UDim2.fromOffset(2, 1)),
		coinsLabel,
		title({ Text = "💪", TextSize = 32, Size = UDim2.fromOffset(48, 40), Position = UDim2.fromOffset(0, 54) }),
		strengthLabel,
	})

	---------------------------------------------------------------- target card (top centre)
	local targetName = body({ Text = "", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, 0, 0, 28), Position = UDim2.fromOffset(16, 8) })
	local targetReward = body({ Text = "", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.4, -44, 0, 28), Position = UDim2.new(0.6, 0, 0, 8) })
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0 }, { corner(9) })
	local healthText = title({ Text = "", TextSize = 20, Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	local card = panel({
		Name = "Target",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(340, 84),
		Visible = false,
		Parent = gui,
	})
	targetName.Parent = card
	targetReward.Parent = card
	coinIcon(22, UDim2.new(1, -38, 0, 11)).Parent = card
	make("Frame", {
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 0, 28),
		BackgroundColor3 = DARK,
		BorderSizePixel = 0,
		Parent = card,
	}, { corner(9), stroke(3), fill, healthText })

	local healthConnection
	local function showTarget()
		if healthConnection then
			healthConnection:Disconnect()
			healthConnection = nil
		end
		local model = Effects.targetModel()
		card.Visible = model ~= nil
		if not model then
			return
		end
		local def = Config.Nuts[model.Name]
		targetName.Text = def.displayName
		targetReward.Text = "+" .. Format(def.reward)
		local function update()
			local health, max = model:GetAttribute("Health"), model:GetAttribute("MaxHealth")
			healthText.Text = `{Format(health)} / {Format(max)}`
			TweenService:Create(fill, TweenInfo.new(0.12), { Size = UDim2.fromScale(math.clamp(health / max, 0, 1), 1) }):Play()
		end
		healthConnection = model:GetAttributeChangedSignal("Health"):Connect(update)
		fill.Size = UDim2.fromScale(1, 1)
		update()
	end
	player:GetAttributeChangedSignal("TargetId"):Connect(showTarget)

	---------------------------------------------------------------- shop button + toasts (bottom centre)
	local shopButton = button("🔨 Shop", ORANGE, {
		Name = "ShopButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(160, 60),
		Parent = gui,
	})
	toasts = make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(520, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { make("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }) })

	---------------------------------------------------------------- shop panel
	local shop = panel({
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(430, 270),
		Visible = false,
		Parent = gui,
	})
	title({ Text = "💪 Strength Shop", TextSize = 36, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -60, 0, 44), Position = UDim2.fromOffset(14, -24), Parent = shop })
	local close = button("X", RED, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(46, 46), Parent = shop })
	body({ Text = "Hit harder to crack tougher nuts!", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 34), Parent = shop })
	local change = body({ RichText = true, TextSize = 46, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 70), Parent = shop })
	local levelLabel = body({ TextColor3 = GREY, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 130), Parent = shop })
	local buy, buyLabel = button("Buy", GREEN, { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(280, 66), Parent = shop })

	---------------------------------------------------------------- "Oops!" popup
	local oops = panel({
		Name = "Oops",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 210),
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	title({ Text = "Oops!", TextSize = 36, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, -24), ZIndex = 6, Parent = oops })
	body({ Text = "You need more Coins\nto buy this upgrade!", TextSize = 24, Size = UDim2.new(1, -30, 0, 80), Position = UDim2.fromOffset(15, 30), ZIndex = 6, Parent = oops })
	local okay, okayLabel = button("Ok!", GREEN, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(170, 58), ZIndex = 6, Parent = oops })
	okayLabel.ZIndex = 7

	---------------------------------------------------------------- state -> UI
	local lastCoins = 0
	local function refresh()
		local coins = player:GetAttribute("Coins") or 0
		local level = player:GetAttribute("StrengthLevel") or 0
		local strength = player:GetAttribute("Strength") or Config.strengthAtLevel(0)

		coinsLabel.Text = Format(coins)
		strengthLabel.Text = Format(strength)
		if coins > lastCoins then
			coinsPulse.Scale = 1.3
			TweenService:Create(coinsPulse, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		lastCoins = coins

		levelLabel.Text = `Level {level} / {Config.MaxStrengthLevel}`
		if level >= Config.MaxStrengthLevel then
			change.Text = `💪 {Format(strength)}`
			buyLabel.Text = "MAX"
			buy.BackgroundColor3 = GREY
		else
			local cost = Config.upgradeCost(level)
			change.Text = `💪 {Format(strength)} <font color="#3cb432">➜ {Format(Config.strengthAtLevel(level + 1))}</font>`
			buyLabel.Text = `Buy: {Format(cost)} Coins`
			buy.BackgroundColor3 = coins >= cost and GREEN or GREY
		end
	end
	for _, name in { "Coins", "StrengthLevel", "Strength" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	---------------------------------------------------------------- actions
	local function setShop(open: boolean)
		shop.Visible = open
		oops.Visible = false
		Effects.play("ui")
	end
	shopButton.Activated:Connect(function()
		setShop(not shop.Visible)
	end)
	close.Activated:Connect(function()
		setShop(false)
	end)
	okay.Activated:Connect(function()
		oops.Visible = false
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" then
			setShop(true)
		end
	end)

	local buying = false
	buy.Activated:Connect(function()
		if buying then
			return
		end
		buying = true
		local ok, result = pcall(Remotes.BuyStrength.InvokeServer, Remotes.BuyStrength)
		buying = false
		if ok and result.ok then
			Effects.play("ui")
			Hud.toast("Strength up! 💪", GREEN)
		elseif ok and result.reason == "coins" then
			oops.Visible = true
		elseif not ok then
			Hud.toast("Purchase failed, try again", RED)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	showTarget()
	Hud.toast(UserInputService.TouchEnabled and "Tap a nut to crack it!" or "Click a nut to crack it!")
end

return Hud
