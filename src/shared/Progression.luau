-- Long-term progression: diamonds, permanent upgrades, rebirth — and the ONE place where multipliers are combined.
-- Server acts on these numbers; the client reads the same functions only to display them.
--
-- What each resource is for (keep them distinct):
--   Coins     -> Strength levels (reset on rebirth) and eggs
--   Strength  -> base damage AND the gate for tougher nuts (nut resistance compares against base Strength only)
--   Pets      -> extra attack units
--   Rebirth   -> resets coins + Strength levels, pays Diamonds, raises the player's own damage multiplier
--   Diamonds  -> permanent upgrades below (never reset)
--
-- Formulas (each multiplier is applied exactly once, here):
--   player damage = round( baseStrength x (1 + StrengthMult) x rebirthMultiplier )
--   pet damage    = round( petBaseDamage x (1 + PetDamage) )          -- per equipped pet
--   coins         = round( nutRewardShare x (1 + CoinMult) )
--   hit interval  = max( MinTickInterval, Config.TickInterval x (1 - AttackSpeed) )
--   walk speed    = min( MaxWalkSpeed, BaseWalkSpeed + WalkSpeed )
--   egg luck      = EggLuck (see PetConfig.eggChances)
local HttpService = game:GetService("HttpService")
local Config = require(script.Parent.Config)

local Progression = {}

Progression.MinTickInterval = 0.2 -- hard floor for the hit interval, whatever the upgrades say
Progression.BaseWalkSpeed = 16
Progression.MaxWalkSpeed = 26

-- cost of level L -> L+1 = round(baseCost x costGrowth^L) diamonds; effect at level L = perLevel x L
-- kind: how the effect is shown ("percent" +30%, "faster" -12%, "flat" +3)
Progression.UpgradeOrder = { "StrengthMult", "CoinMult", "PetDamage", "EggLuck", "AttackSpeed", "WalkSpeed" }
Progression.Upgrades = {
	StrengthMult = {
		name = "Strength Multiplier",
		description = "Your own hits deal more damage",
		icon = "💪",
		color = Color3.fromRGB(255, 82, 96),
		maxLevel = 20,
		baseCost = 3,
		costGrowth = 1.35,
		perLevel = 0.10,
		kind = "percent",
	},
	CoinMult = {
		name = "Coin Multiplier",
		description = "Nuts pay more Coins",
		icon = "💰",
		color = Color3.fromRGB(255, 190, 40),
		maxLevel = 20,
		baseCost = 3,
		costGrowth = 1.35,
		perLevel = 0.10,
		kind = "percent",
	},
	PetDamage = {
		name = "Pet Damage",
		description = "Equipped pets hit harder",
		icon = "🐿",
		color = Color3.fromRGB(160, 110, 255),
		maxLevel = 20,
		baseCost = 3,
		costGrowth = 1.35,
		perLevel = 0.10,
		kind = "percent",
	},
	EggLuck = {
		name = "Egg Luck",
		description = "Rarer pets are more likely",
		icon = "🍀",
		color = Color3.fromRGB(96, 214, 56),
		maxLevel = 10,
		baseCost = 5,
		costGrowth = 1.5,
		perLevel = 0.06,
		kind = "percent",
	},
	AttackSpeed = {
		name = "Attack Speed",
		description = "Less time between hits",
		icon = "⚡",
		color = Color3.fromRGB(60, 190, 230),
		maxLevel = 10,
		baseCost = 6,
		costGrowth = 1.5,
		perLevel = 0.04,
		kind = "faster",
	},
	WalkSpeed = {
		name = "Walk Speed",
		description = "Move faster around the map",
		icon = "👟",
		color = Color3.fromRGB(255, 150, 40),
		maxLevel = 8,
		baseCost = 2,
		costGrowth = 1.4,
		perLevel = 1,
		kind = "flat",
	},
}

-- Rebirth number n (0 = first): needs requirement(n) Coins, pays diamonds(n), damage multiplier becomes multiplier(n+1).
Progression.Rebirth = {
	baseRequirement = 25000,
	requirementGrowth = 2.5,
	baseDiamonds = 10,
	diamondsPerRebirth = 5,
	damagePerRebirth = 0.25,
}

-- One-time diamond rewards (future objectives, bosses and achievements add entries here).
-- Granted through PlayerData.grantOnce, which remembers the key so it can never pay twice.
Progression.OneTimeRewards = {
	FirstPet = { diamonds = 2, label = "First pet hatched" },
	FirstGoldenNut = { diamonds = 3, label = "First Golden Nut cracked" },
}

local function round(x: number): number
	return math.floor(x + 0.5)
end

function Progression.upgradeCost(id: string, level: number): number
	local upgrade = Progression.Upgrades[id]
	return round(upgrade.baseCost * upgrade.costGrowth ^ level)
end

function Progression.effect(id: string, levels): number
	return Progression.Upgrades[id].perLevel * ((levels and levels[id]) or 0)
end

-- "+30%", "-12%" or "+3" for a given level of one upgrade
function Progression.effectText(id: string, level: number): string
	local upgrade = Progression.Upgrades[id]
	local value = upgrade.perLevel * level
	if upgrade.kind == "flat" then
		return "+" .. round(value)
	end
	return (upgrade.kind == "faster" and "-" or "+") .. round(value * 100) .. "%"
end

function Progression.rebirthRequirement(rebirths: number): number
	return math.floor(Progression.Rebirth.baseRequirement * Progression.Rebirth.requirementGrowth ^ rebirths)
end

function Progression.rebirthDiamonds(rebirths: number): number
	return Progression.Rebirth.baseDiamonds + Progression.Rebirth.diamondsPerRebirth * rebirths
end

function Progression.rebirthMultiplier(rebirths: number): number
	return 1 + Progression.Rebirth.damagePerRebirth * rebirths
end

function Progression.playerDamage(baseStrength: number, levels, rebirths: number): number
	return math.max(1, round(baseStrength * (1 + Progression.effect("StrengthMult", levels)) * Progression.rebirthMultiplier(rebirths)))
end

function Progression.petDamage(baseDamage: number, levels): number
	return math.max(1, round(baseDamage * (1 + Progression.effect("PetDamage", levels))))
end

function Progression.coinReward(base: number, levels): number
	return math.max(1, round(base * (1 + Progression.effect("CoinMult", levels))))
end

function Progression.tickInterval(levels): number
	return math.max(Progression.MinTickInterval, Config.TickInterval * (1 - Progression.effect("AttackSpeed", levels)))
end

function Progression.walkSpeed(levels): number
	return math.min(Progression.MaxWalkSpeed, Progression.BaseWalkSpeed + Progression.effect("WalkSpeed", levels))
end

function Progression.luck(levels): number
	return Progression.effect("EggLuck", levels)
end

-- Upgrade levels as replicated in the Player attribute "Upgrades" (JSON written by the server): { [id] = level }
function Progression.readUpgrades(player: Player)
	local ok, levels = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Upgrades"))
	end)
	return ok and type(levels) == "table" and levels or {}
end

return Progression
