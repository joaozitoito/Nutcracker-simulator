-- Strength upgrade purchases. The client sends no data, so there is nothing to forge: price and level come from the server.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local ShopService = {}

function ShopService.start()
	Remotes.BuyStrength.OnServerInvoke = function(player)
		local level = PlayerData.level(player)
		if not level then
			return { ok = false, reason = "notready" }
		end
		if level >= Config.MaxStrengthLevel then
			return { ok = false, reason = "max" }
		end
		-- no yield between the check and the spend, so two fast requests cannot both pass
		if not PlayerData.buyLevel(player, Config.upgradeCost(level)) then
			return { ok = false, reason = "coins" }
		end
		return { ok = true }
	end
end

return ShopService
