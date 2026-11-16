-- Per-player state and the ONLY place that changes it. The table here is the truth; attributes and leaderstats are
-- read-only mirrors for clients. Coins, diamonds, upgrades, rebirth and the pet inventory all go through this module.
--
-- State (also the save format, see Persistence):
--   { version, coins, level, diamonds, rebirths, upgrades = { [id] = level }, claimed = { [rewardKey] = true },
--     discovered = { [petId] = true }, nextPetUid, pets = { { uid, type } }, equipped = { uid } }
-- Reset on rebirth: coins, level.   Kept forever: everything else.
-- "claimed" holds every pay-once reward: Progression.OneTimeRewards keys and Collection milestone keys.
--
-- No function here yields between checking and changing, so two requests can never both pass the same check.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local PetConfig = require(Shared.PetConfig)
local Progression = require(Shared.Progression)
local Collection = require(Shared.Collection)
local Persistence = require(script.Parent.Persistence)

local PlayerData = {}

local VERSION = 3 -- 1 = before diamonds / upgrades / rebirth, 2 = before the pet collection
local LEDGER_SIZE = 50
local AUTOSAVE_SECONDS = 60

local data = {} -- [Player] = state
local ledgers = {} -- [Player] = last diamond operations, newest last (debugging only, never saved)
local sessions = {} -- [Player] = Persistence session (nil when saving is off or the load failed)

---------------------------------------------------------------- loading: defaults, validation, migration
local function defaults()
	return {
		version = VERSION,
		coins = 0,
		level = 0,
		diamonds = 0,
		rebirths = 0,
		upgrades = {},
		claimed = {},
		discovered = {},
		nextPetUid = 1,
		pets = {},
		equipped = {},
	}
end

-- whole number >= 0, or the fallback; rejects NaN, infinities, negatives, strings...
local function count(value, fallback: number, max: number?): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return fallback
	end
	return math.min(math.floor(value), max or 2 ^ 53)
end

-- Turns anything (old save, corrupted save, nil) into a valid state. Never throws; unknown or broken parts fall back
-- to safe defaults. Old versions migrate here simply because every missing field gets its default.
function PlayerData.sanitize(saved)
	local d = defaults()
	if type(saved) ~= "table" then
		return d
	end
	d.coins = count(saved.coins, 0)
	d.level = count(saved.level, 0, Config.MaxStrengthLevel)
	d.diamonds = count(saved.diamonds, 0)
	d.rebirths = count(saved.rebirths, 0)

	if type(saved.upgrades) == "table" then
		for id, upgrade in Progression.Upgrades do
			local level = count(saved.upgrades[id], 0, upgrade.maxLevel)
			if level > 0 then
				d.upgrades[id] = level
			end
		end
	end
	if type(saved.claimed) == "table" then
		for key in Progression.OneTimeRewards do
			if saved.claimed[key] == true then
				d.claimed[key] = true
			end
		end
		for _, milestone in Collection.Milestones do
			if saved.claimed[Collection.key(milestone)] == true then
				d.claimed[Collection.key(milestone)] = true
			end
		end
	end
	-- discovered species: only ids that still exist; accepts the saved map or a plain list
	if type(saved.discovered) == "table" then
		for key, value in saved.discovered do
			local id = value == true and key or value
			if type(id) == "string" and PetConfig.Pets[id] then
				d.discovered[id] = true
			end
		end
	end

	local owned, highest = {}, 0
	if type(saved.pets) == "table" then
		for _, pet in saved.pets do
			if #d.pets >= PetConfig.InventoryCapacity then
				break
			end
			local uid = type(pet) == "table" and count(pet.uid, 0) or 0
			if uid > 0 and not owned[uid] and PetConfig.Pets[pet.type] then
				owned[uid] = true
				highest = math.max(highest, uid)
				table.insert(d.pets, { uid = uid, type = pet.type })
			end
		end
	end
	d.nextPetUid = math.max(count(saved.nextPetUid, 1), highest + 1)
	-- Owning a pet always implies having discovered it. This is also the migration for saves from before the
	-- collection existed: their discovered list starts as the species they currently own.
	for _, pet in d.pets do
		d.discovered[pet.type] = true
	end
	if type(saved.equipped) == "table" then
		for _, uid in saved.equipped do
			if #d.equipped < PetConfig.MaxEquipped and owned[uid] and not table.find(d.equipped, uid) then
				table.insert(d.equipped, uid)
			end
		end
	end
	return d
end

---------------------------------------------------------------- replication
local function sync(player)
	local d = data[player]
	local strength = Config.strengthAtLevel(d.level)
	player:SetAttribute("Coins", d.coins)
	player:SetAttribute("StrengthLevel", d.level)
	player:SetAttribute("Strength", strength)
	player:SetAttribute("Diamonds", d.diamonds)
	player:SetAttribute("Rebirths", d.rebirths)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Coins.Value = d.coins
		stats.Strength.Value = strength
		stats.Rebirths.Value = d.rebirths
	end
end

-- Tables replicate as JSON attributes: late joiners and other clients (pet followers) read the same thing.
local function syncInventory(player)
	local d = data[player]
	player:SetAttribute("Inventory", HttpService:JSONEncode({ pets = d.pets, equipped = d.equipped }))
end

local function syncUpgrades(player)
	local levels = data[player].upgrades
	-- an empty Lua table would encode as [] (array); clients expect an object
	player:SetAttribute("Upgrades", next(levels) and HttpService:JSONEncode(levels) or "{}")
end

local function syncCollection(player)
	local d = data[player]
	local discovered, claimed = {}, {}
	for _, id in PetConfig.PetOrder do
		if d.discovered[id] then
			table.insert(discovered, id)
		end
	end
	for _, milestone in Collection.Milestones do
		if d.claimed[Collection.key(milestone)] then
			table.insert(claimed, Collection.key(milestone))
		end
	end
	player:SetAttribute("Collection", HttpService:JSONEncode({ discovered = discovered, claimed = claimed }))
end

local checkMilestones -- defined with the collection functions below

local function install(player, state)
	data[player] = state
	ledgers[player] = {}
	if not player:FindFirstChild("leaderstats") then
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		for _, name in { "Coins", "Strength", "Rebirths" } do
			local value = Instance.new("IntValue")
			value.Name = name
			value.Parent = stats
		end
		stats.Parent = player
	end
	-- a loaded (or migrated) save may already be past a milestone it was never paid for: settle it now, once
	checkMilestones(player)
	sync(player)
	syncInventory(player)
	syncUpgrades(player)
	syncCollection(player)
end

---------------------------------------------------------------- saving
-- A copy of the state, safe to hand to a DataStore.
function PlayerData.snapshot(player)
	local d = data[player]
	return d and HttpService:JSONDecode(HttpService:JSONEncode(d))
end

local function save(player): boolean
	local session = sessions[player]
	if not session or not data[player] then
		return false -- saving off, or this player's load failed: never write over what is stored
	end
	return session:save(PlayerData.snapshot(player))
end

local function add(player)
	if data[player] then
		return
	end
	local store = Persistence.store()
	if not store then
		install(player, defaults())
		return
	end
	local session, saved = Persistence.open(store, player.UserId) -- yields
	if not player.Parent then
		return
	end
	if session then
		sessions[player] = session
		install(player, PlayerData.sanitize(saved))
	else
		-- load failed: play this session with fresh data, but keep saving OFF for this player
		warn(`[PlayerData] could not load data for {player.Name}; progress will not be saved this session`)
		install(player, defaults())
	end
end

function PlayerData.start()
	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		data[player] = nil
		ledgers[player] = nil
		sessions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(add, player)
	end

	if Persistence.store() then
		task.spawn(function()
			while true do
				task.wait(AUTOSAVE_SECONDS)
				for player in sessions do
					task.spawn(save, player)
				end
			end
		end)
		game:BindToClose(function()
			for player in sessions do
				save(player)
			end
		end)
	end

	-- Dev tool, Studio only: Workspace attribute "DevReload" = true saves everyone to an in-memory store and loads
	-- them back through sanitize, i.e. the same path a real leave + join takes. Result goes to "DevReloadResult".
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("DevReload"):Connect(function()
			if workspace:GetAttribute("DevReload") ~= true then
				return
			end
			local function same(a, b): boolean
				if type(a) ~= "table" or type(b) ~= "table" then
					return a == b
				end
				for key, value in a do
					if not same(value, b[key]) then
						return false
					end
				end
				for key in b do
					if a[key] == nil then
						return false
					end
				end
				return true
			end
			local report = {}
			local memory = Persistence.memoryStore()
			for _, player in Players:GetPlayers() do
				if data[player] then
					local before = data[player]
					local session = Persistence.open(memory, player.UserId)
					local wrote = session:save(PlayerData.snapshot(player))
					local _, loaded = Persistence.open(memory, player.UserId)
					install(player, PlayerData.sanitize(loaded))
					table.insert(report, `{player.Name}: saved={wrote} identical={same(before, data[player])}`)
				end
			end
			workspace:SetAttribute("DevReloadResult", table.concat(report, "; "))
			workspace:SetAttribute("DevReload", false)
		end)
	end
end

---------------------------------------------------------------- reads
function PlayerData.ready(player): boolean
	return data[player] ~= nil
end

function PlayerData.strength(player): number -- base Strength: gates nuts, and is the input of the damage formula
	local d = data[player]
	return d and Config.strengthAtLevel(d.level) or 0
end

function PlayerData.level(player): number?
	local d = data[player]
	return d and d.level
end

function PlayerData.upgrades(player)
	local d = data[player]
	return d and d.upgrades or {}
end

function PlayerData.rebirths(player): number
	local d = data[player]
	return d and d.rebirths or 0
end

function PlayerData.diamonds(player): number
	local d = data[player]
	return d and d.diamonds or 0
end

-- last diamond operations of a player: { { time, change, balance, reason } }
function PlayerData.ledger(player)
	return ledgers[player] or {}
end

---------------------------------------------------------------- coins and strength
function PlayerData.addCoins(player, amount: number)
	local d = data[player]
	if d and amount > 0 then
		d.coins += math.floor(amount)
		sync(player)
	end
end

-- Takes coins if the player has them.
function PlayerData.spend(player, cost: number): boolean
	local d = data[player]
	if not d or cost < 0 or d.coins < cost then
		return false
	end
	d.coins -= cost
	sync(player)
	return true
end

-- Spends coins and raises the strength level in one step; false if the player cannot afford it.
function PlayerData.buyLevel(player, cost: number): boolean
	local d = data[player]
	if not d or d.coins < cost then
		return false
	end
	d.coins -= cost
	d.level += 1
	sync(player)
	return true
end

---------------------------------------------------------------- diamonds
local function recordDiamonds(player, change: number, reason: string)
	local ledger = ledgers[player]
	table.insert(ledger, { time = os.time(), change = change, balance = data[player].diamonds, reason = reason })
	if #ledger > LEDGER_SIZE then
		table.remove(ledger, 1)
	end
end

-- `reason` is free text for the ledger ("rebirth 3", "upgrade CoinMult 4", ...).
function PlayerData.addDiamonds(player, amount: number, reason: string): boolean
	local d = data[player]
	if not d or type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
		return false
	end
	d.diamonds += math.floor(amount)
	recordDiamonds(player, math.floor(amount), reason)
	sync(player)
	return true
end

function PlayerData.spendDiamonds(player, cost: number, reason: string): boolean
	local d = data[player]
	if not d or type(cost) ~= "number" or cost ~= cost or cost < 0 or d.diamonds < cost then
		return false
	end
	d.diamonds -= cost
	recordDiamonds(player, -cost, reason)
	sync(player)
	return true
end

-- The single pay-once mechanism: marks the key as claimed and pays, or does nothing if it was already claimed.
-- The mark is set before paying and nothing here yields, so repeated or simultaneous calls can never pay twice.
local function claim(player, key: string, coins: number, diamonds: number): boolean
	local d = data[player]
	if not d or d.claimed[key] then
		return false
	end
	d.claimed[key] = true
	d.coins += coins
	if diamonds > 0 then
		d.diamonds += diamonds
		recordDiamonds(player, diamonds, "once " .. key)
	end
	return true
end

-- Pays a Progression.OneTimeRewards entry the first time only. Returns the diamonds paid (0 if already claimed).
function PlayerData.grantOnce(player, key: string): number
	local reward = Progression.OneTimeRewards[key]
	if not reward or not claim(player, key, 0, reward.diamonds) then
		return 0
	end
	sync(player)
	return reward.diamonds
end

---------------------------------------------------------------- pet collection
function PlayerData.discoveredCount(player): number
	local d = data[player]
	local total = 0
	if d then
		for _ in d.discovered do
			total += 1
		end
	end
	return total
end

-- Pays every collection milestone the player has reached and not been paid for. Returns the milestones just paid.
-- Safe to call any number of times: claim() remembers each one.
function checkMilestones(player)
	local paid = {}
	local reached = PlayerData.discoveredCount(player)
	for _, milestone in Collection.Milestones do
		if reached >= milestone.species and claim(player, Collection.key(milestone), milestone.coins, milestone.diamonds) then
			table.insert(paid, milestone)
		end
	end
	return paid
end
PlayerData.checkMilestones = checkMilestones

---------------------------------------------------------------- permanent upgrades
-- Buys one level of an upgrade with diamonds. Returns (ok, reason).
function PlayerData.buyUpgrade(player, id: string): (boolean, string?)
	local d = data[player]
	local upgrade = Progression.Upgrades[id]
	if not d then
		return false, "notready"
	end
	if not upgrade then
		return false, "invalid"
	end
	local level = d.upgrades[id] or 0
	if level >= upgrade.maxLevel then
		return false, "max"
	end
	if not PlayerData.spendDiamonds(player, Progression.upgradeCost(id, level), `upgrade {id} {level + 1}`) then
		return false, "diamonds"
	end
	d.upgrades[id] = level + 1
	syncUpgrades(player)
	return true
end

---------------------------------------------------------------- rebirth
-- Checks the requirement, resets the normal progression and pays the reward, all in one step.
-- Returns (true, { diamonds, rebirths }) or (false, reason).
function PlayerData.rebirth(player): (boolean, any)
	local d = data[player]
	if not d then
		return false, "notready"
	end
	if d.coins < Progression.rebirthRequirement(d.rebirths) then
		return false, "coins"
	end
	local diamonds = Progression.rebirthDiamonds(d.rebirths)
	d.coins = 0
	d.level = 0
	d.rebirths += 1
	d.diamonds += diamonds
	recordDiamonds(player, diamonds, "rebirth " .. d.rebirths)
	sync(player)
	return true, { diamonds = diamonds, rebirths = d.rebirths }
end

---------------------------------------------------------------- pets
function PlayerData.petCount(player): number
	local d = data[player]
	return d and #d.pets or 0
end

-- Adds one pet with a fresh uid. This is the only way a pet enters an inventory, so it is also where a species
-- becomes discovered and where collection milestones are paid.
-- Returns (pet, isNewSpecies, milestonesJustPaid), or nil if the type is unknown or the inventory is full.
function PlayerData.addPet(player, petType: string)
	local d = data[player]
	if not d or type(petType) ~= "string" or not PetConfig.Pets[petType] or #d.pets >= PetConfig.InventoryCapacity then
		return nil
	end
	local pet = { uid = d.nextPetUid, type = petType }
	d.nextPetUid += 1
	table.insert(d.pets, pet)
	local isNew = not d.discovered[petType]
	local paid = {}
	if isNew then
		d.discovered[petType] = true
		paid = checkMilestones(player)
		if #paid > 0 then
			sync(player)
		end
		syncCollection(player)
	end
	syncInventory(player)
	return pet, isNew, paid
end

-- Equips or unequips one owned pet. Returns (ok, reason).
function PlayerData.setEquipped(player, uid: number, equip: boolean): (boolean, string?)
	local d = data[player]
	if not d then
		return false, "notready"
	end
	local owned = false
	for _, pet in d.pets do
		if pet.uid == uid then
			owned = true
			break
		end
	end
	if not owned then
		return false, "notowned"
	end
	local slot = table.find(d.equipped, uid)
	if equip then
		if slot then
			return false, "already"
		end
		if #d.equipped >= PetConfig.MaxEquipped then
			return false, "full"
		end
		table.insert(d.equipped, uid)
	else
		if not slot then
			return false, "already"
		end
		table.remove(d.equipped, slot)
	end
	syncInventory(player)
	return true
end

-- Pet type ids of the equipped pets, in equip order.
function PlayerData.equippedPets(player): { string }
	local d = data[player]
	local types = {}
	if d then
		for _, uid in d.equipped do
			for _, pet in d.pets do
				if pet.uid == uid then
					table.insert(types, pet.type)
					break
				end
			end
		end
	end
	return types
end

return PlayerData
