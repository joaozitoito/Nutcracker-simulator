-- All pet and egg data. Adding a pet or an egg = adding an entry here (plus an outfit in PetModel if it needs new looks).
-- Server acts on it (prices, odds, damage); client only reads it for display.
local HttpService = game:GetService("HttpService")

local PetConfig = {}

PetConfig.MaxEquipped = 3 -- pets attacking / following at once
PetConfig.InventoryCapacity = 50

-- damage = damage this pet deals per server tick to its owner's assigned nut (added on top of the player's Strength)
-- look   = { fur, belly, outfit, accent?, scale? } consumed by PetModel.build
PetConfig.PetOrder = { "Nibbles", "Dusty", "Quackers", "Scout", "McNutty", "SirCrunch", "Merlnut", "Captain", "KingWalnut", "Cosmo" }
PetConfig.Pets = {
	Nibbles = {
		displayName = "Nibbles",
		rarity = "Common",
		damage = 1,
		look = { fur = Color3.fromRGB(200, 110, 55), belly = Color3.fromRGB(250, 222, 180), outfit = "plain" },
	},
	Dusty = {
		displayName = "Dusty",
		rarity = "Common",
		damage = 1,
		look = { fur = Color3.fromRGB(150, 150, 165), belly = Color3.fromRGB(240, 240, 245), outfit = "scarf", accent = Color3.fromRGB(235, 70, 70) },
	},
	Quackers = {
		displayName = "Quackers",
		rarity = "Uncommon",
		damage = 2,
		look = { fur = Color3.fromRGB(200, 110, 55), belly = Color3.fromRGB(250, 222, 180), outfit = "duck" },
	},
	Scout = {
		displayName = "Acorn Scout",
		rarity = "Uncommon",
		damage = 3,
		look = { fur = Color3.fromRGB(170, 95, 50), belly = Color3.fromRGB(245, 215, 170), outfit = "scout", accent = Color3.fromRGB(90, 190, 80) },
	},
	McNutty = {
		displayName = "MC Nutty",
		rarity = "Rare",
		damage = 8,
		look = { fur = Color3.fromRGB(205, 115, 60), belly = Color3.fromRGB(250, 222, 180), outfit = "rapper" },
	},
	SirCrunch = {
		displayName = "Sir Crunch",
		rarity = "Rare",
		damage = 10,
		look = { fur = Color3.fromRGB(190, 100, 50), belly = Color3.fromRGB(250, 222, 180), outfit = "knight" },
	},
	Merlnut = {
		displayName = "Merlnut",
		rarity = "Epic",
		damage = 22,
		look = { fur = Color3.fromRGB(200, 110, 55), belly = Color3.fromRGB(250, 222, 180), outfit = "wizard" },
	},
	Captain = {
		displayName = "Captain Chestnut",
		rarity = "Epic",
		damage = 28,
		look = { fur = Color3.fromRGB(140, 80, 50), belly = Color3.fromRGB(240, 205, 160), outfit = "pirate" },
	},
	KingWalnut = {
		displayName = "King Walnut",
		rarity = "Legendary",
		damage = 70,
		look = { fur = Color3.fromRGB(255, 195, 50), belly = Color3.fromRGB(255, 240, 190), outfit = "king", scale = 1.15 },
	},
	Cosmo = {
		displayName = "Cosmo",
		rarity = "Legendary",
		damage = 110,
		look = { fur = Color3.fromRGB(110, 70, 220), belly = Color3.fromRGB(190, 160, 255), outfit = "cosmic", scale = 1.15 },
	},
}

-- pets = { { pet id, weight } }: chance = weight / sum of weights. Weights of every egg add up to 100, so weight = %.
-- currency: only "Coins" exists today.
PetConfig.EggOrder = { "AcornEgg", "ForestEgg", "RoyalEgg" }
PetConfig.Eggs = {
	AcornEgg = {
		displayName = "Acorn Egg",
		price = 50,
		currency = "Coins",
		available = true,
		pets = { { "Nibbles", 45 }, { "Dusty", 35 }, { "Quackers", 15 }, { "Scout", 5 } },
		look = { shell = Color3.fromRGB(240, 200, 140), spots = Color3.fromRGB(200, 130, 70), deco = "acorn" },
	},
	ForestEgg = {
		displayName = "Forest Egg",
		price = 750,
		currency = "Coins",
		available = true,
		pets = { { "Quackers", 35 }, { "Scout", 35 }, { "McNutty", 15 }, { "SirCrunch", 10 }, { "Merlnut", 5 } },
		look = { shell = Color3.fromRGB(120, 205, 110), spots = Color3.fromRGB(60, 150, 80), deco = "leaves" },
	},
	RoyalEgg = {
		displayName = "Royal Egg",
		price = 8000,
		currency = "Coins",
		available = true,
		pets = { { "McNutty", 30 }, { "SirCrunch", 30 }, { "Merlnut", 22 }, { "Captain", 13 }, { "KingWalnut", 4 }, { "Cosmo", 1 } },
		look = { shell = Color3.fromRGB(160, 110, 255), spots = Color3.fromRGB(255, 200, 40), deco = "crown" },
	},
}

-- Picks a pet from an egg. `roll` is a number in [0, 1); the server passes its own random number, never the client's.
function PetConfig.rollPet(eggId: string, roll: number): string
	local pets = PetConfig.Eggs[eggId].pets
	local total = 0
	for _, entry in pets do
		total += entry[2]
	end
	local threshold = roll * total
	for _, entry in pets do
		threshold -= entry[2]
		if threshold < 0 then
			return entry[1]
		end
	end
	return pets[#pets][1]
end

-- Inventory as replicated in the Player attribute "Inventory" (JSON written by the server's PlayerData):
-- { pets = { { uid = number, type = pet id }, ... }, equipped = { uid, ... } }
function PetConfig.readInventory(player: Player)
	local raw = player:GetAttribute("Inventory")
	local ok, inventory = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if ok and type(inventory) == "table" then
		inventory.pets = inventory.pets or {}
		inventory.equipped = inventory.equipped or {}
		return inventory
	end
	return { pets = {}, equipped = {} }
end

return PetConfig
