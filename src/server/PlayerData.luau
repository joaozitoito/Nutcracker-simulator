-- Per-player state and the ONLY place that changes it. The table here is the truth; attributes and leaderstats are
-- read-only mirrors for clients. Every inventory operation (add / equip / unequip) goes through this module.
--
-- Persistence (not implemented yet): `PlayerData.snapshot(player)` returns exactly what a DataStore should save and
-- `add(player, saved)` is where a loaded snapshot would be passed in. Nothing else needs to know about saving.
--   snapshot = { coins, level, nextPetUid, pets = { { uid, type } }, equipped = { uid } }
-- shortcut: nothing is saved between sessions, add a DataStore when the place is published.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local PetConfig = require(Shared.PetConfig)

local PlayerData = {}
local data = {} -- [Player] = snapshot table (see above)

local function sync(player)
	local d = data[player]
	local strength = Config.strengthAtLevel(d.level)
	player:SetAttribute("Coins", d.coins)
	player:SetAttribute("StrengthLevel", d.level)
	player:SetAttribute("Strength", strength)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Coins.Value = d.coins
		stats.Strength.Value = strength
	end
end

-- Inventory replicates as one JSON attribute: late joiners and other clients (pet followers) read the same thing.
local function syncInventory(player)
	local d = data[player]
	player:SetAttribute("Inventory", HttpService:JSONEncode({ pets = d.pets, equipped = d.equipped }))
end

local function add(player, saved)
	if data[player] then
		return
	end
	data[player] = saved or { coins = 0, level = 0, nextPetUid = 1, pets = {}, equipped = {} }
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Coins", "Strength" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
	sync(player)
	syncInventory(player)
end

function PlayerData.start()
	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(function(player)
		data[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		add(player)
	end
end

function PlayerData.snapshot(player)
	return data[player]
end

---------------------------------------------------------------- coins and strength
function PlayerData.strength(player): number
	local d = data[player]
	return d and Config.strengthAtLevel(d.level) or 0
end

function PlayerData.level(player): number?
	local d = data[player]
	return d and d.level
end

function PlayerData.addCoins(player, amount: number)
	local d = data[player]
	if d then
		d.coins += amount
		sync(player)
	end
end

-- Takes coins if the player has them. Check and spend happen in one step with no yield in between.
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

---------------------------------------------------------------- pets
function PlayerData.petCount(player): number
	local d = data[player]
	return d and #d.pets or 0
end

-- Adds one pet of `petType` with a fresh uid. Returns the pet record, or nil if the inventory is full.
function PlayerData.addPet(player, petType: string)
	local d = data[player]
	if not d or #d.pets >= PetConfig.InventoryCapacity then
		return nil
	end
	local pet = { uid = d.nextPetUid, type = petType }
	d.nextPetUid += 1
	table.insert(d.pets, pet)
	syncInventory(player)
	return pet
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
