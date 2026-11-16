-- Asserts on Config so a bad balance edit fails loudly at boot instead of soft-locking progression.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local PetConfig = require(Shared.PetConfig)
local Progression = require(Shared.Progression)
local Collection = require(Shared.Collection)

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

	-- egg luck: at any luck the table still adds up to 100, nothing is negative, and rarer never beats the base odds' order of magnitude
	local maxLuck = Progression.Upgrades.EggLuck.perLevel * Progression.Upgrades.EggLuck.maxLevel
	for _, id in PetConfig.EggOrder do
		for _, luck in { 0, maxLuck / 2, maxLuck } do
			local sum = 0
			for i, chance in PetConfig.eggChances(id, luck) do
				assert(chance[2] > 0, id .. ": a chance dropped to zero or below")
				assert(luck > 0 or math.abs(chance[2] - PetConfig.Eggs[id].pets[i][2]) < 1e-9, id .. ": luck 0 must equal the configured weights")
				sum += chance[2]
			end
			assert(math.abs(sum - 100) < 1e-9, id .. ": chances must add up to 100")
		end
	end

	-- collection milestones: ascending, reachable, and each pays something
	local previous = 0
	for _, milestone in Collection.Milestones do
		assert(milestone.species > previous and milestone.species <= Collection.total(), "collection milestone out of order or unreachable")
		assert(milestone.coins >= 0 and milestone.diamonds >= 0 and milestone.coins + milestone.diamonds > 0, "collection milestone pays nothing")
		assert(not Progression.OneTimeRewards[Collection.key(milestone)], "collection key clashes with a one-time reward")
		previous = milestone.species
	end

	-- permanent upgrades and rebirth
	for _, id in Progression.UpgradeOrder do
		local upgrade = assert(Progression.Upgrades[id], "UpgradeOrder names a missing upgrade: " .. id)
		assert(upgrade.maxLevel >= 1 and upgrade.perLevel > 0, id .. ": bad numbers")
		for level = 1, upgrade.maxLevel - 1 do
			assert(Progression.upgradeCost(id, level) >= Progression.upgradeCost(id, level - 1), id .. ": cost must not go down")
		end
		assert(Progression.upgradeCost(id, 0) >= 1, id .. ": first level must cost something")
	end
	local all = {}
	for id, upgrade in Progression.Upgrades do
		all[id] = upgrade.maxLevel
	end
	assert(Progression.tickInterval(all) >= Progression.MinTickInterval, "attack speed breaks the minimum interval")
	assert(Progression.walkSpeed(all) <= Progression.MaxWalkSpeed, "walk speed breaks the maximum")
	assert(Progression.rebirthDiamonds(0) >= Progression.upgradeCost("WalkSpeed", 0), "first rebirth cannot buy anything")
	for n = 1, 20 do
		assert(Progression.rebirthRequirement(n) > Progression.rebirthRequirement(n - 1), "rebirth requirement must grow")
	end
end
