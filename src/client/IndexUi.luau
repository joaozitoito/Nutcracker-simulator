-- Pet Index: the catalog of every species (straight from PetConfig), which ones this player has discovered, and the
-- collection milestone rewards. Display only: discoveries and rewards are decided by the server and arrive through
-- the Player attributes "Collection" and "Inventory". This module sends no requests at all.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Collection = require(Shared.Collection)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local PetConfig = require(Shared.PetConfig)
local PetModel = require(Shared.PetModel)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)

local IndexUi = {}

local player = Players.LocalPlayer
local C = Ui.Color
local make = Ui.make
local TEAL = Color3.fromRGB(40, 190, 160)

-- rarities that actually have pets, most common first
local function rarityGroups()
	local groups, byName = {}, {}
	for _, id in PetConfig.PetOrder do
		local rarity = PetConfig.Pets[id].rarity
		if not byName[rarity] then
			byName[rarity] = { name = rarity, pets = {} }
			table.insert(groups, byName[rarity])
		end
		table.insert(byName[rarity].pets, id)
	end
	table.sort(groups, function(a, b)
		return Config.Rarities[a.name].order < Config.Rarities[b.name].order
	end)
	return groups
end

-- Banner for a milestone the server just paid. Waits for an egg reveal to finish so it never covers it.
function IndexUi.reward(species: number, coins: number, diamonds: number)
	local root = Hud.root
	task.spawn(function()
		while root:FindFirstChild("EggOpening") do
			task.wait(0.2)
		end
		local banner, face = Ui.card({ color = TEAL, radius = 20, depth = 6 }, {
			Name = "CollectionReward",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6), -- top edge: over the hint pill, clear of an open panel's content
			Size = UDim2.fromOffset(360, 96),
			ZIndex = 25,
			Parent = root,
		})
		Ui.text({ Text = "COLLECTION REWARD!", TextSize = 24, TextColor3 = C.gold, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), Parent = face })
		Ui.text({ Text = `{species} pets discovered`, TextSize = 15, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 32), Parent = face })
		Ui.coin(28, { Position = UDim2.fromOffset(70, 54), Parent = face })
		Ui.text({ Text = "+" .. Format(coins), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(90, 30), Position = UDim2.fromOffset(98, 54), Parent = face })
		Ui.diamond(28, { Position = UDim2.fromOffset(206, 54), Parent = face })
		Ui.text({ Text = "+" .. Format(diamonds), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(90, 30), Position = UDim2.fromOffset(240, 54), Parent = face })
		Ui.pop(banner, true)
		Effects.play("buy")
		task.wait(3.5)
		Ui.pop(banner, false)
		task.wait(0.15)
		banner:Destroy()
	end)
end

function IndexUi.start()
	local root = Hud.root
	local button = Hud.addMenuButton("IndexButton", "📖 INDEX", TEAL)
	local countTag = Ui.tag("", C.night, { Name = "Count", Size = UDim2.fromOffset(46, 24), Position = UDim2.new(1, -30, 0, -12), ZIndex = 4, Parent = button })

	local panel, face, close = Ui.panel({ title = "PET INDEX", color = TEAL }, { Name = "Index", Parent = root })
	local _, setProgress = Ui.bar({ color = TEAL, textSize = 15 }, { Name = "Progress", Position = UDim2.fromOffset(14, 70), Size = UDim2.new(1, -28, 0, 28), Parent = face })
	local list = make("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(10, 104),
		Size = UDim2.fromOffset(402, 232),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.ink,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = face,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }),
	})

	-- milestone rewards: built once, only their state changes
	local rewardsRow = make("Frame", { Name = "Rewards", LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.fromOffset(384, 92), Parent = list })
	local milestones = {} -- { milestone, card, state }
	for i, milestone in Collection.Milestones do
		local card, cardFace = Ui.card({ color = C.sand, radius = 14, depth = 4 }, {
			Name = "Milestone" .. milestone.species,
			Position = UDim2.fromOffset((i - 1) * 130, 0),
			Size = UDim2.fromOffset(124, 92),
			Parent = rewardsRow,
		})
		Ui.label({ Text = `{milestone.species} PETS`, TextSize = 17, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 4), Parent = cardFace })
		Ui.coin(18, { Position = UDim2.fromOffset(10, 28), Parent = cardFace })
		Ui.label({ Text = Format(milestone.coins), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(40, 18), Position = UDim2.fromOffset(28, 28), Parent = cardFace })
		Ui.diamond(18, { Position = UDim2.fromOffset(70, 28), Parent = cardFace })
		Ui.label({ Text = Format(milestone.diamonds), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(30, 18), Position = UDim2.fromOffset(92, 28), Parent = cardFace })
		local state = Ui.tag("", C.grey, { Size = UDim2.fromOffset(108, 26), Position = UDim2.fromOffset(8, 54), Parent = cardFace })
		state.Label.TextSize = 13
		table.insert(milestones, { milestone = milestone, card = card, state = state })
	end

	-- pet cards: one section per rarity, rebuilt when the collection or the inventory changes
	local sections = {}
	local function rebuild()
		for _, section in sections do
			section:Destroy()
		end
		table.clear(sections)

		local collection = Collection.read(player)
		local owned = {}
		for _, pet in PetConfig.readInventory(player).pets do
			owned[pet.type] = (owned[pet.type] or 0) + 1
		end

		local total = Collection.total()
		setProgress(collection.count / total, `{collection.count} / {total} DISCOVERED`)
		countTag.Label.Text = `{collection.count}/{total}`
		for _, entry in milestones do
			local claimed = collection.claimed[Collection.key(entry.milestone)]
			local reached = collection.count >= entry.milestone.species
			if claimed then
				entry.state.Label.Text = "✓ CLAIMED"
				entry.state.BackgroundColor3 = C.gold
			elseif reached then
				entry.state.Label.Text = "UNLOCKED"
				entry.state.BackgroundColor3 = C.green
			else
				entry.state.Label.Text = `🔒 {collection.count}/{entry.milestone.species}`
				entry.state.BackgroundColor3 = C.grey
			end
			Ui.setCardColor(entry.card, claimed and Color3.fromRGB(255, 236, 170) or reached and Color3.fromRGB(200, 245, 180) or C.sand)
		end

		for order, group in rarityGroups() do
			local color = Config.Rarities[group.name].color
			local rows = math.ceil(#group.pets / 2)
			local section = make("Frame", { Name = group.name, LayoutOrder = order + 1, BackgroundTransparency = 1, Size = UDim2.fromOffset(384, 30 + rows * 92 - 8), Parent = list })
			table.insert(sections, section)
			local header = Ui.tag(group.name:upper(), color, { Size = UDim2.fromOffset(120, 24), Parent = section })
			header.Label.TextSize = 14

			for i, id in group.pets do
				local pet = PetConfig.Pets[id]
				local found = collection.discovered[id] == true
				local card, cardFace = Ui.card({ color = found and color:Lerp(C.white, 0.6) or Color3.fromRGB(205, 200, 215), radius = 14, depth = 4 }, {
					Name = id,
					Position = UDim2.fromOffset(((i - 1) % 2) * 194, 30 + math.floor((i - 1) / 2) * 92),
					Size = UDim2.fromOffset(188, 84),
					Parent = section,
				})
				local view = Ui.viewport(PetModel.build(pet.look), { Size = UDim2.fromOffset(74, 74), Position = UDim2.fromOffset(4, 3), Parent = cardFace })
				if found then
					Ui.label({ Text = pet.displayName, TextSize = 15, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(100, 20), Position = UDim2.fromOffset(82, 8), Parent = cardFace })
					Ui.label({ Text = `⚔ {Format(pet.damage)} damage`, TextSize = 13, TextColor3 = Ui.shade(color, 0.45), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(100, 18), Position = UDim2.fromOffset(82, 32), Parent = cardFace })
					local count = owned[id] or 0
					Ui.label({ Text = count > 0 and `Owned x{count}` or "None owned", TextSize = 13, TextColor3 = count > 0 and Ui.shade(C.green, 0.4) or C.grey, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(100, 18), Position = UDim2.fromOffset(82, 52), Parent = cardFace })
				else
					-- silhouette only: the model is drawn in solid dark, name and damage stay hidden
					view.ImageColor3 = Color3.new(0, 0, 0)
					view.ImageTransparency = 0.25
					Ui.label({ Text = "???", TextSize = 22, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(100, 26), Position = UDim2.fromOffset(82, 12), Parent = cardFace })
					Ui.label({ Text = "🔒 Not discovered", TextSize = 12, TextColor3 = Color3.fromRGB(110, 105, 125), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(104, 18), Position = UDim2.fromOffset(82, 44), Parent = cardFace })
				end
				card.LayoutOrder = i
			end
		end
	end

	-- a new discovery: refresh, nudge the button and say which pet it was
	local known = Collection.read(player).discovered
	local function onChange()
		local now = Collection.read(player).discovered
		for id in now do
			if not known[id] then
				Ui.bump(button, 1.12)
				Hud.toast(`New pet discovered: {PetConfig.Pets[id].displayName}!`, TEAL)
			end
		end
		known = now
		rebuild()
	end
	player:GetAttributeChangedSignal("Collection"):Connect(onChange)
	player:GetAttributeChangedSignal("Inventory"):Connect(rebuild)

	button.Activated:Connect(function()
		Hud.toggle(panel)
	end)
	close.Activated:Connect(function()
		Hud.modal(nil)
	end)
	rebuild()
end

return IndexUi
