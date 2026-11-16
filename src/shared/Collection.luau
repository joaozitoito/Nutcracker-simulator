-- Pet collection: which species a player has ever obtained, and the rewards for reaching discovery milestones.
-- The species list itself is PetConfig (no second catalog here). Server pays the rewards; the client only displays.
--
-- Reward sizing (see Progression / PetConfig for the economy):
--   3 species  -> reachable with Acorn Eggs alone (50 Coins each): worth about 5 eggs, plus one cheap upgrade level
--   6 species  -> needs Forest Eggs (750 each): worth about 3 of them, plus roughly one early rebirth of Diamonds
--   10 species -> needs both Royal Egg legendaries (4% and 1%): one first-rebirth's worth of Coins, three rebirths of Diamonds
-- Each is paid once per player, ever (key remembered in PlayerData `claimed`).
local HttpService = game:GetService("HttpService")
local PetConfig = require(script.Parent.PetConfig)

local Collection = {}

Collection.Milestones = {
	{ species = 3, coins = 250, diamonds = 3 },
	{ species = 6, coins = 2500, diamonds = 8 },
	{ species = 10, coins = 25000, diamonds = 30 },
}

-- key under which a milestone is remembered as paid
function Collection.key(milestone): string
	return "Collection" .. milestone.species
end

function Collection.total(): number
	return #PetConfig.PetOrder
end

-- Collection state as replicated in the Player attribute "Collection" (JSON written by the server):
--   { discovered = { petId, ... }, claimed = { "Collection3", ... } }
-- Returns { discovered = { [petId] = true }, count, claimed = { [key] = true } }.
function Collection.read(player: Player)
	local ok, raw = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Collection"))
	end)
	local state = { discovered = {}, count = 0, claimed = {} }
	if ok and type(raw) == "table" then
		for _, id in raw.discovered or {} do
			if PetConfig.Pets[id] and not state.discovered[id] then
				state.discovered[id] = true
				state.count += 1
			end
		end
		for _, key in raw.claimed or {} do
			state.claimed[key] = true
		end
	end
	return state
end

return Collection
