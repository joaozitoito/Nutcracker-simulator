-- HUD built from the Ui kit: stats + upgrade progress, target card / hint, shop button, toasts, shop panel, popup.
-- Reads everything from replicated attributes; the only request it sends is BuyStrength.
--
-- Layout adapts to the screen (desktop / phone landscape / phone portrait), it does not just shrink.
-- Dev tool: set the ScreenGui attribute `PreviewSize` (Vector2) to render the HUD as if the screen had that size.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Effects = require(script.Parent.Effects)
local Ui = require(script.Parent.Ui)

local Hud = {}

local player = Players.LocalPlayer
local C = Ui.Color
local make = Ui.make

local root, uiScale, toasts, coinIcon

function Hud.toast(text: string, color: Color3?)
	if not toasts then
		return
	end
	local card, face = Ui.card({ color = color or C.night, radius = 20, depth = 4 }, { Size = UDim2.fromOffset(340, 44), Parent = toasts })
	Ui.text({ Text = text, TextSize = 22, Size = UDim2.fromScale(1, 1), Parent = face })
	Ui.pop(card, true)
	task.delay(1.9, function()
		Ui.pop(card, false)
		task.wait(0.12)
		card:Destroy()
	end)
end

-- Coins fly from the broken nut to the coin counter.
function Hud.reward(amount: number, worldPosition: Vector3)
	if not root then
		return
	end
	local camera = workspace.CurrentCamera
	local screen = camera:WorldToScreenPoint(worldPosition + Vector3.new(0, 3, 0))
	local s = uiScale.Scale
	local from = (Vector2.new(screen.X, screen.Y) - root.AbsolutePosition) / s
	local to = (coinIcon.AbsolutePosition - root.AbsolutePosition) / s
	local count = math.clamp(math.floor(math.log10(amount + 1) * 3), 3, 9)
	for i = 1, count do
		local coin = Ui.coin(30, {
			Position = UDim2.fromOffset(from.X + math.random(-40, 40), from.Y + math.random(-30, 30)),
			ZIndex = 20,
			Parent = root,
		})
		Ui.pop(coin, true)
		task.delay(0.15 + i * 0.04, function()
			local tween = Ui.tween(coin, 0.4, { Position = UDim2.fromOffset(to.X + 10, to.Y + 10) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween.Completed:Once(function()
				coin:Destroy()
				Ui.bump(coinIcon, 1.3)
			end)
		end)
	end
end

function Hud.start()
	local gui = make("ScreenGui", { Name = "NutHud", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	root = make("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	uiScale = make("UIScale", { Parent = root })

	---------------------------------------------------------------- stats: coins, strength, progress to next upgrade
	local stats = make("Frame", { Name = "Stats", Size = UDim2.fromOffset(210, 222), BackgroundTransparency = 1, Parent = root })

	local function pill(name: string, icon: GuiObject, y: number)
		local card, face = Ui.card({ color = C.night, radius = 26, depth = 5 }, {
			Name = name,
			Size = UDim2.fromOffset(196, 54),
			Position = UDim2.fromOffset(12, y),
			Parent = stats,
		})
		icon.Position = UDim2.fromOffset(-14, -4)
		icon.ZIndex = 3
		icon.Parent = card
		return Ui.text({
			Name = "Value",
			Text = "0",
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(56, 0),
			Size = UDim2.new(1, -62, 1, 0),
			Parent = face,
		})
	end

	coinIcon = Ui.coin(60)
	local coinsValue = pill("Coins", coinIcon, 0)
	coinIcon.Position = UDim2.fromOffset(-8, -6)
	local diamondIcon = Ui.diamond(58)
	local diamondsValue = pill("Diamonds", diamondIcon, 62)
	local strengthIcon = Ui.iconTile("💪", C.red, 58)
	local strengthValue = pill("Strength", strengthIcon, 124)
	-- damage multiplier from rebirth + Strength Multiplier, shown only once the player has one
	local multiplierTag = Ui.tag("", C.red, { Name = "Multiplier", Size = UDim2.fromOffset(58, 24), Position = UDim2.new(1, -52, 0, -10), ZIndex = 4, Visible = false, Parent = strengthValue.Parent.Parent })
	local progress, setProgress = Ui.bar({ color = C.gold, textSize = 15 }, {
		Name = "Progress",
		Size = UDim2.fromOffset(196, 28),
		Position = UDim2.fromOffset(12, 188),
		Parent = stats,
	})

	---------------------------------------------------------------- target card (shown while a nut is assigned)
	local target, targetFace = Ui.card({ color = C.panel, radius = 20, depth = 6 }, {
		Name = "Target",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(380, 102),
		Visible = false,
		Parent = root,
	})
	local tile, tileFace = Ui.card({ color = C.sand, radius = 16, depth = 4 }, { Size = UDim2.fromOffset(76, 78), Position = UDim2.fromOffset(12, 10), Parent = targetFace })
	local rarityTag = Ui.tag("", C.grey, { Position = UDim2.fromOffset(6, -14), ZIndex = 3, Parent = target })
	local targetName = Ui.label({ TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(100, 10), Size = UDim2.fromOffset(170, 30), Parent = targetFace })
	local targetReward = Ui.text({ TextSize = 22, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -152, 0, 10), Size = UDim2.fromOffset(104, 30), Parent = targetFace })
	Ui.coin(26, { Position = UDim2.new(1, -42, 0, 12), Parent = targetFace })
	local _, setHealth = Ui.bar({ color = C.green, textSize = 18 }, { Position = UDim2.fromOffset(100, 50), Size = UDim2.new(1, -114, 0, 30), Parent = targetFace })

	---------------------------------------------------------------- hint (shown while no nut is assigned)
	local hint, hintFace = Ui.card({ color = C.night, radius = 24, depth = 4 }, {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(310, 50),
		Parent = root,
	})
	Ui.text({
		Text = UserInputService.TouchEnabled and "👆 Tap a nut to crack it!" or "👆 Click a nut to crack it!",
		TextSize = 22,
		Size = UDim2.fromScale(1, 1),
		Parent = hintFace,
	})

	local healthConnection, icon
	local function showTarget()
		if healthConnection then
			healthConnection:Disconnect()
			healthConnection = nil
		end
		local model = Effects.targetModel()
		hint.Visible = model == nil
		if not model then
			Ui.pop(target, false)
			return
		end
		local def = Config.Nuts[model.Name]
		local rarity = Config.Rarities[def.rarity]
		targetName.Text = def.displayName
		targetReward.Text = "+" .. Format(def.reward)
		rarityTag.BackgroundColor3 = rarity.color
		rarityTag.Label.Text = def.rarity:upper()
		Ui.setCardColor(tile, rarity.color:Lerp(C.white, 0.55))
		if icon then
			icon:Destroy()
		end
		icon = Ui.nutIcon(def.look, 56, { Position = UDim2.fromOffset(10, 8), Parent = tileFace })

		local function update()
			local health, max = model:GetAttribute("Health"), model:GetAttribute("MaxHealth")
			local fraction = health / max
			setHealth(fraction, `{Format(health)} / {Format(max)}`, fraction > 0.5 and C.green or fraction > 0.25 and C.gold or C.red)
		end
		healthConnection = model:GetAttributeChangedSignal("Health"):Connect(update)
		update()
		Ui.pop(target, true)
		Effects.play("ui")
	end
	player:GetAttributeChangedSignal("TargetId"):Connect(showTarget)

	---------------------------------------------------------------- shop button (+ "you can afford it" badge) and toasts
	-- menu: every feature adds its button here, layout() decides if the row is horizontal or vertical
	-- above the dim and the panels (ZIndex 13): with a panel open the menu still works, so one tap switches panels
	local menu = make("Frame", { Name = "Menu", BackgroundTransparency = 1, ZIndex = 13, Parent = root })
	local menuGrid = make("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	local menuCount = 0
	local layout -- defined at the end of start(); adding a button re-runs it
	function Hud.addMenuButton(name: string, text: string, color: Color3)
		menuCount += 1
		local button, label = Ui.button({ text = text, color = color, textSize = 22 }, { Name = name, LayoutOrder = menuCount, Parent = menu })
		-- labels shrink to fit the smaller phone cells instead of clipping
		label.TextScaled = true
		label.TextWrapped = false -- one line: shrink the text instead of splitting "UPGRADES" in two
		label.Size = UDim2.new(1, -14, 1, -12)
		label.Position = UDim2.fromOffset(7, 6)
		make("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 10, Parent = label })
		if layout then
			layout()
		end
		return button
	end
	local shopButton = Hud.addMenuButton("ShopButton", "🔨 SHOP", C.orange)
	local badge = Ui.iconTile("!", C.red, 30, { Name = "Badge", Position = UDim2.new(1, -18, 0, -12), ZIndex = 4, Visible = false, Parent = shopButton })
	toasts = make("Frame", { Name = "Toasts", Size = UDim2.fromOffset(340, 150), BackgroundTransparency = 1, Parent = root })
	local toastList = make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = toasts })

	---------------------------------------------------------------- shop panel
	local dim = make("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(4, 4),
		Position = UDim2.fromScale(-1.5, -1.5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
		Parent = root,
	})
	local shop, shopFace = Ui.card({ color = C.panel, radius = 24, depth = 8 }, {
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 340),
		Visible = false,
		ZIndex = 11,
		Parent = root,
	})
	make("Frame", { Size = UDim2.new(1, -12, 0, 58), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = C.orange, BorderSizePixel = 0, Parent = shopFace }, {
		Ui.corner(18),
		Ui.text({ Text = "STRENGTH SHOP", TextSize = 30, Size = UDim2.fromScale(1, 1) }),
	})
	local close = Ui.button({ text = "X", color = C.red, textSize = 24, depth = 4, radius = 14 }, {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(50, 50),
		ZIndex = 3,
		Parent = shop,
	})

	Ui.iconTile("💪", C.red, 78, { Position = UDim2.fromOffset(18, 80), Parent = shopFace })
	local function statBox(caption: string, color: Color3, x: number, width: number)
		local _, face = Ui.card({ color = color, radius = 14, depth = 4 }, { Size = UDim2.fromOffset(width, 82), Position = UDim2.fromOffset(x, 78), Parent = shopFace })
		Ui.label({ Text = caption, TextSize = 14, TextColor3 = Ui.shade(color, 0.5), Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 4), Parent = face })
		return Ui.label({ TextSize = 36, Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 26), Parent = face })
	end
	local nowValue = statBox("NOW", C.sand, 110, 110)
	Ui.label({ Text = ">", TextSize = 40, TextColor3 = C.green, Size = UDim2.fromOffset(36, 82), Position = UDim2.fromOffset(222, 76), Parent = shopFace })
	local nextValue = statBox("NEXT", Color3.fromRGB(190, 240, 160), 260, 142)
	local gainTag = Ui.tag("", C.green, { Size = UDim2.fromOffset(62, 26), Position = UDim2.fromOffset(350, 66), ZIndex = 3, Parent = shopFace })
	local _, setLevel = Ui.bar({ color = C.purple, textSize = 15 }, { Position = UDim2.fromOffset(18, 176), Size = UDim2.new(1, -36, 0, 26), Parent = shopFace })
	local need = Ui.label({ TextSize = 17, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 208), Parent = shopFace })
	local buy, buyLabel, buyFace = Ui.button({ text = "BUY", color = C.green, textSize = 30 }, {
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.new(1, -36, 0, 76),
		Parent = shop,
	})
	local buyCoin = Ui.coin(40, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 22, 0.5, 0), ZIndex = 3, Parent = buyFace })

	---------------------------------------------------------------- "Oops!" popup
	local oops, oopsFace = Ui.card({ color = C.panel, radius = 24, depth = 8 }, {
		Name = "Oops",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 250),
		Visible = false,
		ZIndex = 12,
		Parent = root,
	})
	make("Frame", { Size = UDim2.new(1, -12, 0, 58), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = C.red, BorderSizePixel = 0, Parent = oopsFace }, {
		Ui.corner(18),
		Ui.text({ Text = "OOPS!", TextSize = 32, Size = UDim2.fromScale(1, 1) }),
	})
	local oopsText = Ui.label({ TextSize = 22, TextWrapped = true, Size = UDim2.new(1, -40, 0, 84), Position = UDim2.fromOffset(20, 68), Parent = oopsFace })
	local okay = Ui.button({ text = "Ok!", color = C.green }, { Name = "Ok", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(170, 62), Parent = oops })

	---------------------------------------------------------------- state -> UI
	local shownCoins = make("NumberValue")
	shownCoins.Changed:Connect(function(value)
		coinsValue.Text = Format(math.floor(value + 0.5))
	end)
	local lastStrength
	local function refresh()
		local coins = player:GetAttribute("Coins") or 0
		local level = player:GetAttribute("StrengthLevel") or 0
		local strength = player:GetAttribute("Strength") or Config.strengthAtLevel(0)

		Ui.tween(shownCoins, 0.35, { Value = coins }) -- count up / down instead of jumping
		strengthValue.Text = Format(strength)
		if lastStrength and strength > lastStrength then
			Ui.bump(strengthIcon, 1.4)
		end
		lastStrength = strength

		nowValue.Text = Format(strength)
		setLevel(level / Config.MaxStrengthLevel, `LEVEL {level} / {Config.MaxStrengthLevel}`)
		if level >= Config.MaxStrengthLevel then
			progress.Visible = false
			badge.Visible = false
			nextValue.Text = "MAX"
			gainTag.Visible = false
			need.Text = ""
			buyLabel.Text = "MAX LEVEL"
			buyCoin.Visible = false
			Ui.setCardColor(buy, C.grey)
			return
		end

		-- a rebirth brings the level back from MAX, so undo what the MAX branch hid
		progress.Visible, gainTag.Visible, buyCoin.Visible = true, true, true
		local cost = Config.upgradeCost(level)
		local nextStrength = Config.strengthAtLevel(level + 1)
		local affordable = coins >= cost
		nextValue.Text = Format(nextStrength)
		gainTag.Label.Text = "+" .. Format(nextStrength - strength)
		buyLabel.Text = "BUY   " .. Format(cost)
		Ui.setCardColor(buy, affordable and C.green or C.grey)
		need.Text = affordable and "You can afford this upgrade!" or `Need {Format(cost - coins)} more Coins`
		need.TextColor3 = affordable and Ui.shade(C.green, 0.35) or C.red
		setProgress(coins / cost, affordable and "UPGRADE READY!" or `NEXT UPGRADE  {Format(coins)} / {Format(cost)}`, affordable and C.green or C.gold)
		if affordable and not badge.Visible then
			Ui.pop(badge, true)
		end
		badge.Visible = affordable
	end
	for _, name in { "Coins", "StrengthLevel", "Strength" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end

	-- diamonds and the player's damage multiplier (rebirth x Strength Multiplier upgrade)
	local lastDiamonds
	local function refreshProgression()
		local diamonds = player:GetAttribute("Diamonds") or 0
		diamondsValue.Text = Format(diamonds)
		if lastDiamonds and diamonds > lastDiamonds then
			Ui.bump(diamondIcon, 1.4)
		end
		lastDiamonds = diamonds
		local multiplier = Progression.playerDamage(1000, Progression.readUpgrades(player), player:GetAttribute("Rebirths") or 0) / 1000
		multiplierTag.Visible = multiplier > 1
		multiplierTag.Label.Text = string.format("x%.2f", multiplier)
	end
	for _, name in { "Diamonds", "Rebirths", "Upgrades" } do
		player:GetAttributeChangedSignal(name):Connect(refreshProgression)
	end
	refreshProgression()

	---------------------------------------------------------------- actions
	-- One modal panel at a time over a dimmed screen. Hud.modal(panel) opens it, Hud.modal(nil) closes whatever is open.
	local current
	local modalPosition = UDim2.fromScale(0.5, 0.5) -- where panels sit; layout() moves it clear of the menu on phones
	function Hud.modal(panel: GuiObject?)
		if panel == current then
			return
		end
		Effects.play("ui")
		if current then
			Ui.pop(current, false)
		end
		Ui.pop(oops, false)
		current = panel
		if panel then
			panel.Position = modalPosition
			Ui.pop(panel, true)
		end
		dim.Visible = true
		local fade = Ui.tween(dim, 0.15, { BackgroundTransparency = panel and 0.5 or 1 })
		if not panel then
			fade.Completed:Once(function()
				dim.Visible = dim.BackgroundTransparency < 0.9
			end)
		end
	end
	function Hud.toggle(panel: GuiObject)
		Hud.modal(current ~= panel and panel or nil)
	end
	function Hud.oops(text: string)
		oopsText.Text = text
		Effects.play("deny")
		Ui.pop(oops, true)
	end
	Hud.root = root

	shopButton.Activated:Connect(function()
		Hud.toggle(shop)
	end)
	close.Activated:Connect(function()
		Hud.modal(nil)
	end)
	dim.Activated:Connect(function()
		Hud.modal(nil)
	end)
	okay.Activated:Connect(function()
		Ui.pop(oops, false)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" then
			Hud.modal(shop)
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
			Effects.play("buy")
			Ui.bump(nextValue.Parent.Parent, 1.12)
			Hud.toast("Strength up! 💪", C.green)
		elseif ok and result.reason == "coins" then
			local level = player:GetAttribute("StrengthLevel") or 0
			Hud.oops(`You need {Format(Config.upgradeCost(level) - (player:GetAttribute("Coins") or 0))} more Coins to buy this upgrade!`)
		elseif not ok then
			Hud.toast("Purchase failed, try again", C.red)
		end
	end)

	---------------------------------------------------------------- responsive layout
	-- menu as a grid: `columns` cells per row, sized so it never needs more room than the screen has
	local function arrangeMenu(columns: number, width: number, height: number)
		local rows = math.ceil(math.max(menuCount, 1) / columns)
		local used = math.min(columns, math.max(menuCount, 1))
		menuGrid.CellSize = UDim2.fromOffset(width, height)
		menuGrid.CellPadding = UDim2.fromOffset(10, 10)
		menuGrid.FillDirectionMaxCells = columns
		menu.Size = UDim2.fromOffset(used * width + (used - 1) * 10, rows * height + (rows - 1) * 10)
	end

	layout = function()
		local preview = gui:GetAttribute("PreviewSize")
		root.BackgroundTransparency = preview and 0.7 or 1
		root.BackgroundColor3 = Color3.new(0, 0, 0)
		local size = preview or gui.AbsoluteSize
		local compact = math.min(size.X, size.Y) < 520
		local portrait = size.Y > size.X

		if not compact then
			-- desktop / tablet: stats at mid-left like the genre, shop bottom centre
			uiScale.Scale = math.clamp(size.Y / 640, 0.8, 1.5)
			stats.AnchorPoint, stats.Position = Vector2.new(0, 0.5), UDim2.new(0, 14, 0.5, 0)
			target.Position = UDim2.new(0.5, 0, 0, 22)
			menu.AnchorPoint, menu.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -14)
			arrangeMenu(8, 150, 66) -- one row
			modalPosition = UDim2.fromScale(0.5, 0.47)
			toasts.AnchorPoint, toasts.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -92)
			toastList.VerticalAlignment = Enum.VerticalAlignment.Bottom
		elseif not portrait then
			-- phone landscape: bottom corners belong to the thumbstick and jump button
			uiScale.Scale = math.clamp(math.min(size.X / 820, size.Y / 370), 0.55, 1)
			stats.AnchorPoint, stats.Position = Vector2.zero, UDim2.fromOffset(10, 8)
			target.Position = UDim2.new(0.5, 0, 0, 20)
			menu.AnchorPoint, menu.Position = Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0)
			arrangeMenu(2, 128, 62) -- two columns on the right edge
			modalPosition = UDim2.new(0.5, -145, 0.5, 0) -- panels sit left of the menu column
			toasts.AnchorPoint, toasts.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 132)
			toastList.VerticalAlignment = Enum.VerticalAlignment.Top
		else
			-- phone portrait: stack stats and target vertically
			uiScale.Scale = math.clamp(size.X / 440, 0.6, 1)
			stats.AnchorPoint, stats.Position = Vector2.zero, UDim2.fromOffset(10, 8)
			target.Position = UDim2.new(0.5, 0, 0, 240)
			menu.AnchorPoint, menu.Position = Vector2.new(1, 0), UDim2.new(1, -10, 0, 446)
			arrangeMenu(2, 128, 62)
			modalPosition = UDim2.new(0.5, 0, 0, 250) -- panels sit above the menu block
			toasts.AnchorPoint, toasts.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 352)
			toastList.VerticalAlignment = Enum.VerticalAlignment.Top
		end
		hint.Position = target.Position
		oops.Position = modalPosition
		if current then
			current.Position = modalPosition
		end
		-- a UIScale also shrinks the frame it sits in, so size the root up by the inverse to keep covering the screen
		local s = uiScale.Scale
		root.Size = preview and UDim2.fromOffset(preview.X / s, preview.Y / s) or UDim2.fromScale(1 / s, 1 / s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	gui:GetAttributeChangedSignal("PreviewSize"):Connect(layout)

	gui.Parent = player:WaitForChild("PlayerGui")
	layout()
	refresh()
	showTarget()
end

return Hud
