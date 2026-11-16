-- Asserts on Config so a bad balance edit fails loudly at boot instead of soft-locking progression.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)

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
end
