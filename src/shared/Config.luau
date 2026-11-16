-- All tunable game data lives here. Server is the only one that acts on it; the client only reads it for display.
local Config = {}

Config.TickInterval = 0.4 -- seconds between automatic hits on the assigned nut
Config.AssignRange = 22 -- max studs between player and nut to assign it
Config.LeashRange = 28 -- walking further than this drops the assignment
Config.ManualHitCooldown = 0.15 -- seconds between manual (click) hits accepted by the server

-- zone = which band of the field the nut spawns in (1 = closest to spawn)
-- resistance = minimum Strength needed to damage it at all
Config.NutOrder = { "Acorn", "Walnut", "GoldenNut" }
Config.Nuts = {
	Acorn = {
		displayName = "Acorn",
		zone = 1,
		count = 14,
		health = 10,
		reward = 5,
		resistance = 1,
		respawn = 4,
		look = {
			shape = "acorn",
			scale = 1,
			body = Color3.fromRGB(222, 150, 80),
			cap = Color3.fromRGB(130, 80, 45),
		},
	},
	Walnut = {
		displayName = "Walnut",
		zone = 2,
		count = 9,
		health = 150,
		reward = 45,
		resistance = 5,
		respawn = 7,
		look = {
			shape = "walnut",
			scale = 1.5,
			body = Color3.fromRGB(176, 104, 58),
			cap = Color3.fromRGB(120, 66, 36),
		},
	},
	GoldenNut = {
		displayName = "Golden Nut",
		zone = 3,
		count = 4,
		health = 1500,
		reward = 500,
		resistance = 25,
		respawn = 12,
		look = {
			shape = "acorn",
			scale = 2.1,
			body = Color3.fromRGB(255, 205, 50),
			cap = Color3.fromRGB(255, 160, 20),
			sparkle = true,
		},
	},
}

Config.MaxStrengthLevel = 30

-- Strength (= damage per hit) at a given upgrade level. Strictly increasing.
function Config.strengthAtLevel(level: number): number
	return 1 + level + math.floor(level * level / 3)
end

-- Coins needed to go from `level` to `level + 1`.
function Config.upgradeCost(level: number): number
	return math.floor(10 * 1.5 ^ level)
end

return Config
