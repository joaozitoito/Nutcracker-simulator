-- Hammer evolution: five looks for the player's mallet, unlocked by progress the game already tracks.
-- Purely cosmetic: nothing here touches damage, attack speed, rewards or rebirth math.
--
-- Unlock rules (checked on the server in PlayerData, highest tier ever reached is kept forever):
--   1 Starter Mallet     from the start
--   2 Acorn Crusher      base Strength >= Walnut resistance      (you can crack Walnuts)       ~3 Strength levels
--   3 Forest Maul        base Strength >= Golden Nut resistance  (you can crack Golden Nuts)   ~8 Strength levels
--   4 Royal Breaker      1 rebirth                                                              25k Coins earned
--   5 Cosmic Pulverizer  3 rebirths                                                             ~245k Coins earned
-- Strength resets on rebirth, which is why the reached tier is stored and never goes down.
--
-- fx = what one confirmed hit looks like on the nut (see Effects.impact):
--   pieces/shape/colors/size  flying bits;  motion "fall" (gravity), "drift" (float down) or "burst" (shoot out, shrink)
--   ring = colour of the shock ring, ringSize = its final diameter (studs, before nut scale)
--   neon / light / flash      glowing bits, a short light, an expanding sphere
local Config = require(script.Parent.Config)

local Hammers = {}

Hammers.Tiers = {
	{
		id = "Starter",
		name = "Starter Mallet",
		color = Color3.fromRGB(214, 160, 100),
		need = {},
		fx = { pieces = 4, shape = "block", size = 0.35, motion = "fall", colors = { Color3.fromRGB(214, 160, 100), Color3.fromRGB(150, 100, 60) }, ring = Color3.fromRGB(240, 220, 190), ringSize = 6 },
	},
	{
		id = "AcornCrusher",
		name = "Acorn Crusher",
		color = Color3.fromRGB(230, 150, 70),
		need = { strength = Config.Nuts.Walnut.resistance },
		fx = { pieces = 6, shape = "blob", size = 0.5, motion = "fall", colors = { Color3.fromRGB(230, 160, 85), Color3.fromRGB(125, 76, 42) }, ring = Color3.fromRGB(255, 210, 150), ringSize = 8 },
	},
	{
		id = "ForestMaul",
		name = "Forest Maul",
		color = Color3.fromRGB(110, 200, 90),
		need = { strength = Config.Nuts.GoldenNut.resistance },
		fx = { pieces = 6, shape = "leaf", size = 0.6, motion = "drift", colors = { Color3.fromRGB(110, 200, 90), Color3.fromRGB(70, 160, 70), Color3.fromRGB(255, 190, 60) }, ring = Color3.fromRGB(170, 230, 140), ringSize = 9 },
	},
	{
		id = "RoyalBreaker",
		name = "Royal Breaker",
		color = Color3.fromRGB(255, 200, 40),
		need = { rebirths = 1 },
		fx = { pieces = 8, shape = "spark", size = 0.35, motion = "burst", neon = true, colors = { Color3.fromRGB(255, 210, 60), Color3.fromRGB(255, 250, 220) }, ring = Color3.fromRGB(255, 210, 60), ringSize = 11, light = Color3.fromRGB(255, 200, 80) },
	},
	{
		id = "CosmicPulverizer",
		name = "Cosmic Pulverizer",
		color = Color3.fromRGB(170, 110, 255),
		need = { rebirths = 3 },
		fx = { pieces = 8, shape = "star", size = 0.45, motion = "burst", neon = true, colors = { Color3.fromRGB(180, 110, 255), Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 255, 255) }, ring = Color3.fromRGB(160, 100, 255), ringSize = 13, light = Color3.fromRGB(170, 110, 255), flash = true },
	},
}

local function met(tier, strength: number, rebirths: number): boolean
	return strength >= (tier.need.strength or 0) and rebirths >= (tier.need.rebirths or 0)
end

-- Highest tier the current numbers qualify for (tiers are ordered, each one implies the ones before it).
function Hammers.tierFor(strength: number, rebirths: number): number
	local best = 1
	for i, tier in Hammers.Tiers do
		if met(tier, strength, rebirths) then
			best = i
		end
	end
	return best
end

-- "Reach 25 Strength", "Rebirth 3 times", ...
function Hammers.requirementText(index: number): string
	local need = Hammers.Tiers[index].need
	if need.rebirths then
		return need.rebirths == 1 and "Rebirth once" or `Rebirth {need.rebirths} times`
	elseif need.strength then
		return `Reach {need.strength} Strength`
	end
	return "Unlocked from the start"
end

return Hammers
