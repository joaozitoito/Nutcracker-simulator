-- Server bootstrap. Order matters: map gives the nut spawn points.
require(script.SelfCheck)()
local spawnPoints = require(script.MapBuilder).build()
require(script.PlayerData).start()
require(script.NutService).start(spawnPoints)
require(script.ShopService).start()
require(script.PetService).start()

-- Dev tool, Studio only: set the Workspace attribute "DevCoins" from the server command bar to give everyone coins.
-- Clients cannot write server attributes, and this never runs in a published game.
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("DevCoins"):Connect(function()
		local amount = workspace:GetAttribute("DevCoins")
		if type(amount) == "number" and amount ~= 0 then
			for _, player in game:GetService("Players"):GetPlayers() do
				require(script.PlayerData).addCoins(player, amount)
			end
			workspace:SetAttribute("DevCoins", 0)
		end
	end)
end
