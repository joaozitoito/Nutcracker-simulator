-- Asserts on Config so a bad balance edit fails loudly at boot instead of soft-locking progression.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local PetConfig = require(Shared.PetConfig)

return function()
	local maxStrength = Config.strengthAtLevel(Config.MaxStrengthLevel)
	for level = 1, Config.MaxStrengthLevel do
		assert(Config.strengthAtLevel(level) > Config.strengthAtLevel(level - 1), "strength must grow every level")
		assert(Config.upgradeCost(level) > Config.upgradeCost(level - 1), "cost must grow every level")
	end
	assert(Config.upgradeCost(0) >= 1, "first upgrade must cost something")
	assert(Config.LeashRange >= Config.AssignRange, "leash shorter than assign range would drop targets instantly")

	local startStrength = Config.strengthAtLevel(0)
	local starter = false
	for _, name in Config.NutOrder do
		local def = assert(Config.Nuts[name], "NutOrder names a missing nut: " .. name)
		assert(def.health > 0 and def.reward > 0 and def.respawn > 0 and def.count > 0, name .. ": bad numbers")
		assert(Config.Rarities[def.rarity], name .. ": unknown rarity")
		assert(def.resistance <= maxStrength, name .. ": can never be cracked")
		starter = starter or def.resistance <= startStrength
	end
	assert(starter, "no nut is crackable at starting strength")

	-- pets and eggs
	for _, id in PetConfig.PetOrder do
		local pet = assert(PetConfig.Pets[id], "PetOrder names a missing pet: " .. id)
		assert(Config.Rarities[pet.rarity], id .. ": unknown rarity")
		assert(pet.damage > 0, id .. ": damage must be positive")
	end
	local cheapest = math.huge
	for _, id in PetConfig.EggOrder do
		local egg = assert(PetConfig.Eggs[id], "EggOrder names a missing egg: " .. id)
		assert(egg.currency == "Coins", id .. ": only Coins can pay for eggs")
		assert(egg.price > 0, id .. ": price must be positive")
		local total = 0
		for _, entry in egg.pets do
			assert(PetConfig.Pets[entry[1]], id .. " drops an unknown pet: " .. tostring(entry[1]))
			assert(entry[2] > 0, id .. ": weights must be positive")
			total += entry[2]
		end
		assert(total == 100, id .. ": weights must add up to 100 so they read as percentages")
		assert(PetConfig.Pets[PetConfig.rollPet(id, 0)] and PetConfig.Pets[PetConfig.rollPet(id, 0.999999)], id .. ": roll")
		cheapest = math.min(cheapest, egg.price)
	end
	assert(PetConfig.MaxEquipped <= PetConfig.InventoryCapacity, "cannot equip more pets than fit in the inventory")
end
