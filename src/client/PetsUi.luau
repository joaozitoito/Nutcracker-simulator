-- Pet screens built from the Ui kit and plugged into the HUD: PETS and EGGS menu buttons, inventory with details and
-- equip, egg catalog with odds, and the egg opening sequence.
-- State comes from the Player attribute "Inventory"; the only requests sent are OpenEgg(eggId) and EquipPet(uid, bool).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local PetConfig = require(Shared.PetConfig)
local PetModel = require(Shared.PetModel)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)

local PetsUi = {}

local player = Players.LocalPlayer
local C = Ui.Color
local make = Ui.make

local function rarityColor(petType: string): Color3
	return Config.Rarities[PetConfig.Pets[petType].rarity].color
end

-- invisible button covering a card, so whole cards are clickable
local function clickArea(parent: Instance)
	return make("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = parent })
end

local function invoke(remote: RemoteFunction, ...)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if ok and type(result) == "table" then
		return result
	end
	return { ok = false, reason = "network" }
end

---------------------------------------------------------------- egg opening sequence
-- Presentation only: by the time this runs the server has already put the pet in the inventory,
-- so skipping it, dying or leaving in the middle loses nothing and cannot grant anything twice.
local opening = false

local function playOpening(eggId: string, petType: string, onDone: () -> ())
	local egg, pet = PetConfig.Eggs[eggId], PetConfig.Pets[petType]
	local rarity = Config.Rarities[pet.rarity]
	local tier = rarity.order -- 1..5, drives how big the reveal is

	local overlay = make("TextButton", {
		Name = "EggOpening",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(4, 4),
		Position = UDim2.fromScale(-1.5, -1.5),
		BackgroundColor3 = Color3.fromRGB(20, 12, 34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 30,
		Parent = Hud.root,
	})
	-- stage is a normal-sized frame centred on screen so the content does not depend on the oversized overlay
	local stage = make("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromOffset(420, 350), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 31, Parent = Hud.root })
	Ui.tween(overlay, 0.2, { BackgroundTransparency = 0.25 })

	local skipped = false
	local dismissed = Instance.new("BindableEvent")
	overlay.Activated:Connect(function()
		skipped = true
		dismissed:Fire()
	end)
	local function wait(seconds: number)
		local elapsed = 0
		while elapsed < seconds and not skipped do
			elapsed += task.wait()
		end
	end

	local glow = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = rarity.color,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Parent = stage,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local holder = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 130), Size = UDim2.fromOffset(230, 230), ZIndex = 2, Parent = stage })
	local holderScale = make("UIScale", { Scale = 0.2, Parent = holder })
	local view = Ui.viewport(PetModel.buildEgg(egg.look), { Size = UDim2.fromScale(1, 1), Parent = holder })
	local title = Ui.text({ Text = egg.displayName, TextSize = 34, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 252), ZIndex = 3, Parent = stage })

	-- 1. egg pops in and shakes harder and harder; rarer pets shake longer
	Effects.play("ui")
	Ui.tween(holderScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	wait(0.3)
	local shakes = 6 + tier * 2
	for i = 1, shakes do
		if skipped then
			break
		end
		local angle = (6 + i * 1.6) * (i % 2 == 0 and 1 or -1)
		Ui.tween(holder, 0.08, { Rotation = angle })
		Ui.tween(holderScale, 0.08, { Scale = 1 + i / shakes * 0.25 })
		if i % 3 == 0 then
			Effects.play("hit")
		end
		wait(0.085)
	end
	skipped = false -- a tap during the shake only skips the shake

	-- 2. flash, the egg becomes the pet
	local flash = make("Frame", { Size = UDim2.fromScale(4, 4), Position = UDim2.fromScale(-1.5, -1.5), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 40, Parent = Hud.root })
	Ui.tween(flash, 0.45, { BackgroundTransparency = 1 })
	Effects.play("crack")
	view:Destroy()
	holder.Rotation = 0
	Ui.viewport(PetModel.build(pet.look), { Size = UDim2.fromScale(1, 1), Parent = holder })
	holderScale.Scale = 0.3
	Ui.tween(holderScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	Ui.tween(glow, 0.4, { Size = UDim2.fromOffset(190 + tier * 28, 190 + tier * 28) }, Enum.EasingStyle.Back)

	-- rays behind the pet: more and longer for rarer pets
	local rays = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 130), Size = UDim2.fromOffset(10, 10), Parent = stage })
	for i = 1, tier * 3 do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 250 + tier * 50),
			Rotation = i * 180 / (tier * 3),
			BackgroundColor3 = rarity.color:Lerp(C.white, 0.4),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Parent = rays,
		})
	end
	Ui.tween(rays, 6, { Rotation = 180 }, Enum.EasingStyle.Linear)

	-- 3. name, rarity and attack
	title.Text = pet.displayName
	Ui.bump(title, 1.5)
	local tag = Ui.tag(pet.rarity:upper(), rarity.color, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 294), Size = UDim2.fromOffset(120, 28), ZIndex = 3, Parent = stage })
	Ui.pop(tag, true)
	Ui.text({ Text = `⚔ +{Format(pet.damage)} damage per hit`, TextSize = 20, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 326), ZIndex = 3, Parent = stage })
	if tier >= 4 then
		-- epic and legendary get a second flash and a pulsing glow
		task.delay(0.25, function()
			if flash.Parent then
				flash.BackgroundColor3 = rarity.color
				flash.BackgroundTransparency = 0.4
				Ui.tween(flash, 0.5, { BackgroundTransparency = 1 })
				Effects.play("buy")
			end
		end)
	end

	-- 4. wait for a tap (or a few seconds), then clean everything up
	local timer = task.delay(2.6 + tier * 0.3, function()
		dismissed:Fire()
	end)
	wait(0.4) -- ignore taps that were meant to skip the shake
	skipped = false
	dismissed.Event:Wait()
	pcall(task.cancel, timer)
	dismissed:Destroy()
	overlay:Destroy()
	stage:Destroy()
	flash:Destroy()
	onDone()
end

---------------------------------------------------------------- start: buttons and panels
function PetsUi.start()
	local root = Hud.root
	local petsButton = Hud.addMenuButton("PetsButton", "🐿 PETS", C.purple)
	local eggsButton = Hud.addMenuButton("EggsButton", "🥚 EGGS", Color3.fromRGB(60, 190, 230))
	local equippedTag = Ui.tag("0/" .. PetConfig.MaxEquipped, C.night, { Name = "Equipped", Size = UDim2.fromOffset(46, 24), Position = UDim2.new(1, -30, 0, -12), ZIndex = 4, Parent = petsButton })

	------------------------------------------------------------ inventory panel
	local inventoryPanel, inventoryFace, inventoryClose = Ui.panel({ title = "MY PETS", color = C.purple }, { Name = "Pets", Parent = root })
	local capacityLabel = Ui.text({ TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(120, 20), Position = UDim2.fromOffset(20, 40), ZIndex = 2, Parent = inventoryFace })
	local grid = make("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(12, 72),
		Size = UDim2.fromOffset(240, 258),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.ink,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = inventoryFace,
	}, {
		make("UIGridLayout", { CellSize = UDim2.fromOffset(70, 76), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	local emptyLabel = Ui.label({ Text = "No pets yet!\nOpen an egg to get one.", TextSize = 18, TextColor3 = C.grey, Size = UDim2.fromOffset(240, 80), Position = UDim2.fromOffset(12, 150), Parent = inventoryFace })

	-- details of the selected pet
	local preview, previewFace = Ui.card({ color = C.sand, radius = 16, depth = 4 }, { Position = UDim2.fromOffset(262, 72), Size = UDim2.fromOffset(146, 112), Parent = inventoryFace })
	local detailName = Ui.label({ TextSize = 18, TextScaled = true, Size = UDim2.fromOffset(146, 22), Position = UDim2.fromOffset(262, 188), Parent = inventoryFace })
	local detailTag = Ui.tag("", C.grey, { Position = UDim2.fromOffset(262 + 23, 214), Size = UDim2.fromOffset(100, 22), Parent = inventoryFace })
	local detailDamage = Ui.label({ TextSize = 16, Size = UDim2.fromOffset(146, 20), Position = UDim2.fromOffset(262, 240), Parent = inventoryFace })
	local slotsLabel = Ui.label({ TextSize = 14, TextColor3 = C.grey, Size = UDim2.fromOffset(146, 18), Position = UDim2.fromOffset(262, 260), Parent = inventoryFace })
	local equipButton, equipLabel = Ui.button({ text = "EQUIP", color = C.green, textSize = 22, depth = 5 }, { Name = "Equip", Position = UDim2.fromOffset(262, 280), Size = UDim2.fromOffset(146, 52), Parent = inventoryFace })

	local inventory = { pets = {}, equipped = {} }
	local selectedUid: number?
	local previewView

	local function selected()
		for _, pet in inventory.pets do
			if pet.uid == selectedUid then
				return pet
			end
		end
		return nil
	end

	local function showDetails()
		local pet = selected()
		if previewView then
			previewView:Destroy()
			previewView = nil
		end
		local equippedCount = #inventory.equipped
		slotsLabel.Text = `EQUIPPED {equippedCount} / {PetConfig.MaxEquipped}`
		for _, object in { preview, detailName, detailTag, detailDamage, equipButton } do
			object.Visible = pet ~= nil
		end
		if not pet then
			return
		end
		local def = PetConfig.Pets[pet.type]
		local isEquipped = table.find(inventory.equipped, pet.uid) ~= nil
		Ui.setCardColor(preview, rarityColor(pet.type):Lerp(C.white, 0.55))
		previewView = Ui.viewport(PetModel.build(def.look), { Size = UDim2.fromScale(1, 1), Parent = previewFace })
		detailName.Text = def.displayName
		detailTag.BackgroundColor3 = rarityColor(pet.type)
		detailTag.Label.Text = def.rarity:upper()
		detailDamage.Text = `⚔ +{Format(def.damage)} damage`
		if isEquipped then
			equipLabel.Text = "UNEQUIP"
			Ui.setCardColor(equipButton, C.red)
		elseif equippedCount >= PetConfig.MaxEquipped then
			equipLabel.Text = "SLOTS FULL"
			Ui.setCardColor(equipButton, C.grey)
		else
			equipLabel.Text = "EQUIP"
			Ui.setCardColor(equipButton, C.green)
		end
	end

	local function rebuildGrid()
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		-- equipped first, then rarest, then strongest
		local sorted = table.clone(inventory.pets)
		local function rank(pet)
			local def = PetConfig.Pets[pet.type]
			return (table.find(inventory.equipped, pet.uid) and 1e9 or 0) + Config.Rarities[def.rarity].order * 1e6 + def.damage
		end
		table.sort(sorted, function(a, b)
			local ra, rb = rank(a), rank(b)
			if ra ~= rb then
				return ra > rb
			end
			return a.uid < b.uid
		end)

		for order, pet in sorted do
			local def = PetConfig.Pets[pet.type]
			local tile, face = Ui.card({ color = rarityColor(pet.type):Lerp(C.white, 0.5), radius = 12, depth = 4 }, { Name = "Pet" .. pet.uid, LayoutOrder = order, Parent = grid })
			Ui.viewport(PetModel.build(def.look), { Size = UDim2.new(1, 0, 1, -12), Parent = face })
			Ui.text({ Text = "⚔" .. Format(def.damage), TextSize = 13, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -17), ZIndex = 2, Parent = face })
			if table.find(inventory.equipped, pet.uid) then
				Ui.iconTile("✓", C.green, 22, { Position = UDim2.new(1, -18, 0, -6), ZIndex = 3, Parent = tile })
			end
			if pet.uid == selectedUid then
				tile.UIStroke.Color = C.gold
				tile.UIStroke.Thickness = 5
			end
			clickArea(tile).Activated:Connect(function()
				selectedUid = pet.uid
				Effects.play("ui")
				rebuildGrid()
				showDetails()
			end)
		end
	end

	local function refreshInventory()
		inventory = PetConfig.readInventory(player)
		if not selected() then
			selectedUid = inventory.pets[1] and inventory.pets[1].uid
		end
		emptyLabel.Visible = #inventory.pets == 0
		capacityLabel.Text = `{#inventory.pets} / {PetConfig.InventoryCapacity}`
		equippedTag.Label.Text = `{#inventory.equipped}/{PetConfig.MaxEquipped}`
		rebuildGrid()
		showDetails()
	end
	player:GetAttributeChangedSignal("Inventory"):Connect(refreshInventory)

	local busy = false
	equipButton.Activated:Connect(function()
		local pet = selected()
		if busy or not pet then
			return
		end
		local isEquipped = table.find(inventory.equipped, pet.uid) ~= nil
		if not isEquipped and #inventory.equipped >= PetConfig.MaxEquipped then
			Effects.play("deny")
			Hud.toast(`Only {PetConfig.MaxEquipped} pets can be equipped`, C.red)
			return
		end
		busy = true
		local result = invoke(Remotes.EquipPet, pet.uid, not isEquipped)
		busy = false
		if result.ok then
			Effects.play("buy")
			Ui.bump(petsButton, 1.1)
		else
			Effects.play("deny")
			Hud.toast("Could not change that pet", C.red)
		end
	end)

	------------------------------------------------------------ egg catalog panel
	local eggsPanel, eggsFace, eggsClose = Ui.panel({ title = "PET EGGS", color = Color3.fromRGB(60, 190, 230) }, { Name = "Eggs", Parent = root })
	local selectedEgg = PetConfig.EggOrder[1]
	local eggCards = {}
	for i, id in PetConfig.EggOrder do
		local egg = PetConfig.Eggs[id]
		local card, face = Ui.card({ color = egg.look.shell:Lerp(C.white, 0.55), radius = 14, depth = 5 }, {
			Name = id,
			Position = UDim2.fromOffset(12 + (i - 1) * 134, 72),
			Size = UDim2.fromOffset(128, 150),
			Parent = eggsFace,
		})
		Ui.viewport(PetModel.buildEgg(egg.look), { Size = UDim2.new(1, 0, 0, 92), Parent = face })
		Ui.label({ Text = egg.displayName, TextSize = 16, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 92), Parent = face })
		Ui.coin(20, { Position = UDim2.new(0.5, -38, 0, 116), Parent = face })
		Ui.text({ Text = Format(egg.price), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(70, 22), Position = UDim2.new(0.5, -12, 0, 115), Parent = face })
		eggCards[id] = card
		card.Visible = egg.available
	end

	Ui.label({ Text = "CHANCES", TextSize = 14, TextColor3 = C.grey, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(120, 18), Position = UDim2.fromOffset(16, 226), Parent = eggsFace })
	local odds = make("Frame", { Name = "Odds", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 246), Size = UDim2.fromOffset(250, 84), Parent = eggsFace }, {
		make("UIGridLayout", { CellSize = UDim2.fromOffset(122, 24), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local openButton, openLabel = Ui.button({ text = "OPEN", color = C.green, textSize = 26 }, { Name = "Open", Position = UDim2.fromOffset(274, 236), Size = UDim2.fromOffset(134, 64), Parent = eggsFace })
	local needLabel = Ui.label({ TextSize = 13, Size = UDim2.fromOffset(134, 30), Position = UDim2.fromOffset(274, 302), TextWrapped = true, Parent = eggsFace })

	local function refreshEggs()
		local egg = PetConfig.Eggs[selectedEgg]
		local coins = player:GetAttribute("Coins") or 0
		for id, card in eggCards do
			card.UIStroke.Color = id == selectedEgg and C.gold or C.ink
			card.UIStroke.Thickness = id == selectedEgg and 5 or 3
		end
		for _, child in odds:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		-- the odds shown come from the same function the server rolls with, including this player's Egg Luck
		for order, entry in PetConfig.eggChances(selectedEgg, Progression.luck(Progression.readUpgrades(player))) do
			local percent = entry[2] >= 10 and string.format("%.0f", entry[2]) or string.format("%.1f", entry[2])
			local chip = Ui.tag(`{percent}%  {PetConfig.Pets[entry[1]].displayName}`, rarityColor(entry[1]), { LayoutOrder = order, Parent = odds })
			chip.Label.TextSize = 12
		end
		local full = #inventory.pets >= PetConfig.InventoryCapacity
		local affordable = coins >= egg.price
		Ui.setCardColor(openButton, (affordable and not full) and C.green or C.grey)
		openLabel.Text = "OPEN"
		needLabel.Text = full and "Pet inventory is full" or affordable and `Costs {Format(egg.price)} Coins` or `Need {Format(egg.price - coins)} more Coins`
		needLabel.TextColor3 = (full or not affordable) and C.red or Ui.shade(C.green, 0.35)
	end
	for id, card in eggCards do
		clickArea(card).Activated:Connect(function()
			selectedEgg = id
			Effects.play("ui")
			Ui.bump(card, 1.08)
			refreshEggs()
		end)
	end
	player:GetAttributeChangedSignal("Coins"):Connect(refreshEggs)
	player:GetAttributeChangedSignal("Inventory"):Connect(refreshEggs)
	player:GetAttributeChangedSignal("Upgrades"):Connect(refreshEggs)

	openButton.Activated:Connect(function()
		if opening then
			return
		end
		opening = true
		local eggId = selectedEgg
		local result = invoke(Remotes.OpenEgg, eggId)
		if not result.ok then
			opening = false
			if result.reason == "coins" then
				Hud.oops(`You need {Format(PetConfig.Eggs[eggId].price - (player:GetAttribute("Coins") or 0))} more Coins to open this egg!`)
			elseif result.reason == "full" then
				Hud.oops("Your pet inventory is full!")
			else
				Hud.toast("Could not open the egg, try again", C.red)
			end
			return
		end
		Hud.modal(nil)
		task.spawn(function()
			local ok, err = pcall(playOpening, eggId, result.pet.type, function()
				-- land on the new pet, ready to equip
				selectedUid = result.pet.uid
				refreshInventory()
				Hud.modal(inventoryPanel)
				Hud.toast(`{PetConfig.Pets[result.pet.type].displayName} joined your pets!`, rarityColor(result.pet.type))
			end)
			opening = false
			if not ok then
				warn("[PetsUi] egg opening failed:", err)
				for _, name in { "EggOpening", "Stage" } do
					local leftover = root:FindFirstChild(name)
					if leftover then
						leftover:Destroy()
					end
				end
			end
		end)
	end)

	------------------------------------------------------------ wiring
	petsButton.Activated:Connect(function()
		Hud.toggle(inventoryPanel)
	end)
	eggsButton.Activated:Connect(function()
		Hud.toggle(eggsPanel)
	end)
	inventoryClose.Activated:Connect(function()
		Hud.modal(nil)
	end)
	eggsClose.Activated:Connect(function()
		Hud.modal(nil)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "EggPrompt" then
			Hud.modal(eggsPanel)
		end
	end)

	refreshInventory()
	refreshEggs()
end

return PetsUi
