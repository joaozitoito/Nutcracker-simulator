-- Permanent upgrades and rebirth. The client sends at most an upgrade id; costs, rewards and results are decided here.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local ProgressionService = {}

local function applyWalkSpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Progression.walkSpeed(PlayerData.upgrades(player))
	end
end

function ProgressionService.start()
	Remotes.BuyUpgrade.OnServerInvoke = function(player, id)
		if type(id) ~= "string" then
			return { ok = false, reason = "invalid" }
		end
		local ok, reason = PlayerData.buyUpgrade(player, id)
		if ok and id == "WalkSpeed" then
			applyWalkSpeed(player)
		end
		return { ok = ok, reason = reason }
	end

	-- No arguments are read: the requirement and the reward come from the server's own state.
	Remotes.Rebirth.OnServerInvoke = function(player)
		local ok, result = PlayerData.rebirth(player)
		if not ok then
			return { ok = false, reason = result }
		end
		-- back to the start of the area; the reset itself already happened above, in one step
		task.defer(function()
			if player.Parent then
				player:LoadCharacter()
			end
		end)
		return { ok = true, diamonds = result.diamonds, rebirths = result.rebirths }
	end

	local function watch(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			applyWalkSpeed(player)
		end)
		-- saved data can arrive after the first character spawned: apply again once the upgrades are known
		player:GetAttributeChangedSignal("Upgrades"):Connect(function()
			applyWalkSpeed(player)
		end)
		applyWalkSpeed(player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return ProgressionService
