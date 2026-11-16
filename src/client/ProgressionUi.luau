-- Long-term progression screens plugged into the HUD: UPGRADES (permanent upgrades bought with Diamonds) and REBIRTH.
-- State comes from the Player attributes Diamonds / Rebirths / Upgrades / Coins; numbers come from Shared.Progression,
-- the same functions the server uses. The only requests sent are BuyUpgrade(id) and Rebirth().
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)

local ProgressionUi = {}

local player = Players.LocalPlayer
local C = Ui.Color
local make = Ui.make
local CYAN = Color3.fromRGB(60, 190, 230)
local EMBER = Color3.fromRGB(255, 110, 70)
local DISABLED = Color3.fromRGB(150, 150, 150)

local function invoke(remote: RemoteFunction, ...)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if ok and type(result) == "table" then
		return result
	end
	return { ok = false, reason = "network" }
end

-- full-screen flash + big text after a successful rebirth; removes itself
local function celebrate(rebirths: number, diamonds: number)
	local root = Hud.root
	local flash = make("Frame", { Size = UDim2.fromScale(4, 4), Position = UDim2.fromScale(-1.5, -1.5), BackgroundColor3 = EMBER, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 40, Parent = root })
	local stage = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(420, 160), ZIndex = 41, Parent = root })
	local title = Ui.text({ Text = `REBIRTH {rebirths}!`, TextSize = 58, TextColor3 = C.gold, Size = UDim2.new(1, 0, 0, 70), Parent = stage })
	Ui.text({ Text = `+{Format(diamonds)} Diamonds   •   Damage x{string.format("%.2f", Progression.rebirthMultiplier(rebirths))}`, TextSize = 24, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 78), Parent = stage })
	Ui.tween(flash, 0.7, { BackgroundTransparency = 1 })
	Ui.bump(title, 1.8)
	Effects.play("crack")
	task.delay(2.4, function()
		flash:Destroy()
		stage:Destroy()
	end)
end

function ProgressionUi.start()
	local root = Hud.root
	local upgradesButton = Hud.addMenuButton("UpgradesButton", "💎 UPGRADES", CYAN)
	local rebirthButton = Hud.addMenuButton("RebirthButton", "⭐ REBIRTH", EMBER)
	local rebirthTag = Ui.tag("", C.night, { Name = "Count", Size = UDim2.fromOffset(40, 24), Position = UDim2.new(1, -28, 0, -12), ZIndex = 4, Visible = false, Parent = rebirthButton })
	local rebirthReady = Ui.iconTile("!", C.red, 28, { Name = "Ready", Position = UDim2.new(0, -8, 0, -12), ZIndex = 4, Visible = false, Parent = rebirthButton })

	------------------------------------------------------------ permanent upgrades panel
	local upgradesPanel, upgradesFace, upgradesClose = Ui.panel({ title = "UPGRADES", color = CYAN }, { Name = "Upgrades", Parent = root })
	Ui.diamond(26, { Position = UDim2.fromOffset(18, 22), ZIndex = 2, Parent = upgradesFace })
	local balance = Ui.text({ TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(90, 26), Position = UDim2.fromOffset(48, 22), ZIndex = 2, Parent = upgradesFace })
	local list = make("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(10, 70),
		Size = UDim2.fromOffset(402, 266),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.ink,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = upgradesFace,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6) }),
	})

	local rows = {} -- [id] = { level, effect, buy, buyLabel, gem, max }
	local busy = false
	for order, id in Progression.UpgradeOrder do
		local upgrade = Progression.Upgrades[id]
		local row, face = Ui.card({ color = upgrade.color:Lerp(C.white, 0.72), radius = 14, depth = 4 }, { Name = id, LayoutOrder = order, Size = UDim2.fromOffset(384, 82), Parent = list })
		Ui.iconTile(upgrade.icon, upgrade.color, 50, { Position = UDim2.fromOffset(8, 12), Parent = face })
		Ui.label({ Text = upgrade.name, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 20), Position = UDim2.fromOffset(68, 6), Parent = face })
		Ui.label({ Text = upgrade.description, TextSize = 13, TextColor3 = Ui.shade(upgrade.color, 0.45), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 16), Position = UDim2.fromOffset(68, 27), Parent = face })
		local level = Ui.tag("", C.night, { Size = UDim2.fromOffset(72, 22), Position = UDim2.fromOffset(68, 48), Parent = face })
		local effect = Ui.label({ RichText = true, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(130, 22), Position = UDim2.fromOffset(146, 48), Parent = face })
		local buy, buyLabel = Ui.imageButton({ text = "", textSize = 20 }, { Name = "Buy", Position = UDim2.fromOffset(272, 14), Size = UDim2.fromOffset(104, 50), Parent = face })
		buyLabel.Size = UDim2.new(1, -34, 0.9, 0)
		buyLabel.Position = UDim2.fromOffset(30, 0)
		local gem = Ui.diamond(24, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.45, 0), ZIndex = 3, Parent = buy })
		local max = Ui.tag("MAX", C.gold, { Size = UDim2.fromOffset(84, 30), Position = UDim2.fromOffset(282, 24), Visible = false, Parent = face })
		max.Label.TextSize = 16
		rows[id] = { level = level, effect = effect, buy = buy, buyLabel = buyLabel, gem = gem, max = max }

		buy.Activated:Connect(function()
			if busy then
				return
			end
			local current = Progression.readUpgrades(player)[id] or 0
			local cost = Progression.upgradeCost(id, current)
			if (player:GetAttribute("Diamonds") or 0) < cost then
				Hud.oops(`You need {Format(cost - (player:GetAttribute("Diamonds") or 0))} more Diamonds!\nRebirth to earn Diamonds.`)
				return
			end
			busy = true
			local result = invoke(Remotes.BuyUpgrade, id)
			busy = false
			if result.ok then
				Effects.play("buy")
				Ui.bump(row, 1.06)
				Hud.toast(`{upgrade.name} is now level {current + 1}!`, upgrade.color)
			elseif result.reason == "diamonds" then
				Hud.oops("You need more Diamonds!\nRebirth to earn Diamonds.")
			else
				Hud.toast("Could not buy that upgrade", C.red)
			end
		end)
	end

	local function refreshUpgrades()
		local diamonds = player:GetAttribute("Diamonds") or 0
		local levels = Progression.readUpgrades(player)
		balance.Text = Format(diamonds)
		for id, widgets in rows do
			local upgrade = Progression.Upgrades[id]
			local level = levels[id] or 0
			local maxed = level >= upgrade.maxLevel
			widgets.level.Label.Text = `LV {level}/{upgrade.maxLevel}`
			widgets.buy.Visible = not maxed
			widgets.max.Visible = maxed
			if maxed then
				widgets.effect.Text = Progression.effectText(id, level)
			else
				local cost = Progression.upgradeCost(id, level)
				widgets.effect.Text = `{Progression.effectText(id, level)} <font color="#2f9e1e">> {Progression.effectText(id, level + 1)}</font>`
				widgets.buyLabel.Text = Format(cost)
				Ui.tintImageButton(widgets.buy, diamonds < cost and DISABLED or nil)
			end
		end
	end

	------------------------------------------------------------ rebirth panel
	local rebirthPanel, rebirthFace, rebirthClose = Ui.panel({ title = "REBIRTH", color = EMBER }, { Name = "Rebirth", Parent = root })
	local heading = Ui.label({ TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(220, 30), Position = UDim2.fromOffset(18, 70), Parent = rebirthFace })
	local nextNeed = Ui.label({ TextSize = 13, TextColor3 = C.grey, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(170, 30), Position = UDim2.new(1, -188, 0, 70), Parent = rebirthFace })
	local _, setRequirement = Ui.bar({ color = C.gold, textSize = 15 }, { Name = "Requirement", Position = UDim2.fromOffset(18, 104), Size = UDim2.new(1, -36, 0, 28), Parent = rebirthFace })

	local function rewardCard(x: number, caption: string, color: Color3)
		local _, face = Ui.card({ color = color:Lerp(C.white, 0.7), radius = 14, depth = 4 }, { Size = UDim2.fromOffset(188, 58), Position = UDim2.fromOffset(x, 140), Parent = rebirthFace })
		Ui.label({ Text = caption, TextSize = 12, TextColor3 = Ui.shade(color, 0.45), Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 3), Parent = face })
		return Ui.label({ RichText = true, TextSize = 22, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 20), Parent = face }), face
	end
	local diamondsReward, diamondsFace = rewardCard(18, "YOU GET", CYAN)
	Ui.diamond(26, { Position = UDim2.fromOffset(34, 22), Parent = diamondsFace })
	local multiplierReward = rewardCard(214, "YOUR DAMAGE", C.red)

	local function column(x: number, caption: string, color: Color3, lines: { string })
		Ui.tag(caption, color, { Size = UDim2.fromOffset(92, 22), Position = UDim2.fromOffset(x, 206), Parent = rebirthFace })
		Ui.label({ Text = table.concat(lines, "\n"), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.fromOffset(188, 50), Position = UDim2.fromOffset(x + 4, 232), Parent = rebirthFace })
	end
	column(18, "YOU LOSE", C.red, { "• All Coins", "• Strength levels (shop)" })
	column(214, "YOU KEEP", C.green, { "• Pets and equipped pets", "• Diamonds and Upgrades", "• Rebirth damage bonus" })

	local confirm, confirmLabel = Ui.imageButton({ text = "REBIRTH", textSize = 24 }, { Name = "Confirm", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(384, 50), Parent = rebirthFace })

	local armed = false -- first press arms the button, second press within 3s sends the request
	local function refreshRebirth()
		local coins = player:GetAttribute("Coins") or 0
		local rebirths = player:GetAttribute("Rebirths") or 0
		local requirement = Progression.rebirthRequirement(rebirths)
		local ready = coins >= requirement
		heading.Text = `Rebirth {rebirths}  >  {rebirths + 1}`
		nextNeed.Text = `Next one needs {Format(Progression.rebirthRequirement(rebirths + 1))}`
		setRequirement(coins / requirement, `{Format(math.min(coins, requirement))} / {Format(requirement)} Coins`, ready and C.green or C.gold)
		diamondsReward.Text = "+" .. Format(Progression.rebirthDiamonds(rebirths))
		multiplierReward.Text = string.format('x%.2f <font color="#2f9e1e">> x%.2f</font>', Progression.rebirthMultiplier(rebirths), Progression.rebirthMultiplier(rebirths + 1))
		rebirthTag.Visible = rebirths > 0
		rebirthTag.Label.Text = "x" .. rebirths
		if ready and not rebirthReady.Visible then
			Ui.pop(rebirthReady, true)
		end
		rebirthReady.Visible = ready
		if not ready then
			armed = false
		end
		confirmLabel.Text = armed and "TAP AGAIN TO CONFIRM" or ready and "REBIRTH" or `NEED {Format(requirement - coins)} MORE COINS`
		Ui.tintImageButton(confirm, armed and Color3.fromRGB(255, 140, 120) or not ready and DISABLED or nil)
	end

	local sending = false
	confirm.Activated:Connect(function()
		local rebirths = player:GetAttribute("Rebirths") or 0
		if sending or (player:GetAttribute("Coins") or 0) < Progression.rebirthRequirement(rebirths) then
			Effects.play("deny")
			return
		end
		if not armed then
			armed = true
			Effects.play("ui")
			refreshRebirth()
			task.delay(3, function()
				if armed then
					armed = false
					refreshRebirth()
				end
			end)
			return
		end
		armed = false
		sending = true
		local result = invoke(Remotes.Rebirth) -- the server re-checks everything and decides the reward
		sending = false
		refreshRebirth()
		if result.ok then
			Hud.modal(nil)
			celebrate(result.rebirths, result.diamonds)
		else
			Effects.play("deny")
			Hud.toast(result.reason == "coins" and "Not enough Coins to rebirth" or "Rebirth failed, try again", C.red)
		end
	end)

	------------------------------------------------------------ wiring
	local function refresh()
		refreshUpgrades()
		refreshRebirth()
	end
	for _, name in { "Coins", "Diamonds", "Rebirths", "Upgrades" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	upgradesButton.Activated:Connect(function()
		Hud.toggle(upgradesPanel)
	end)
	rebirthButton.Activated:Connect(function()
		Hud.toggle(rebirthPanel)
	end)
	upgradesClose.Activated:Connect(function()
		Hud.modal(nil)
	end)
	rebirthClose.Activated:Connect(function()
		Hud.modal(nil)
	end)
	refresh()
end

return ProgressionUi
