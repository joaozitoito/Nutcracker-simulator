-- Per-player session state. The table here is the truth; attributes and leaderstats are read-only mirrors for clients.
-- shortcut: nothing is saved between sessions, add a DataStore when the place is published.
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)

local PlayerData = {}
local data = {} -- [Player] = { coins, level }

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

local function add(player)
	if data[player] then
		return
	end
	data[player] = { coins = 0, level = 0 }
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Coins", "Strength" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
	sync(player)
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

return PlayerData
